import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A problem with a profile photo, worded for the customer.
class ProfilePhotoException implements Exception {
  final String message;
  const ProfilePhotoException(this.message);

  @override
  String toString() => message;
}

// ================================================
// PROFILE PHOTO SERVICE
//
// Photos live in the `profile-photos` bucket, one folder per customer
// (named by their user id):  <user id>/avatar_<time>.jpg
//
// Only the PATH is saved on the customer's profile (users.avatar_path).
//
// Who may do what is enforced by Supabase itself, not by this code:
//   - the storage rules let a signed-in customer add, replace or delete files
//     ONLY inside their own folder;
//   - the users table refuses an avatar_path that points outside their folder;
//   - the bucket refuses anything over 2 MB or that is not JPG, PNG or WebP.
// The checks here only give the customer a clear message BEFORE that happens.
// ================================================
class ProfilePhotoService {
  static const String bucket = 'profile-photos';
  static const int maxBytes = 2 * 1024 * 1024; // 2 MB, same as the bucket limit
  static const List<String> pickerExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  final SupabaseClient _supabase = Supabase.instance.client;

  // ── What the file REALLY is ─────────────────────────────────────
  // Looks at the first bytes of the file, not its name, so a file that was
  // just renamed to .jpg is not accepted. Returns 'jpg', 'png' or 'webp',
  // or null when it is none of them.
  static String? detectType(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'jpg';
    }
    if (b.length >= 8 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return 'png';
    }
    // WebP: "RIFF" .... "WEBP"
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  static String contentTypeFor(String type) {
    switch (type) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// A readable reason the photo cannot be used, or null when it is fine.
  static String? check(PlatformFile file) {
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return 'We couldn\'t read that file. Please choose another photo.';
    }

    final String extension =
        (file.extension ?? file.name.split('.').last).toLowerCase();
    if (!pickerExtensions.contains(extension)) {
      return 'Please choose a JPG, PNG or WebP photo.';
    }

    if (bytes.length > maxBytes) {
      return 'That photo is larger than 2 MB. Please choose a smaller one.';
    }

    if (detectType(bytes) == null) {
      return 'That file isn\'t a valid JPG, PNG or WebP image.';
    }
    return null;
  }

  /// The picture's web address, or null when there is no photo.
  String? publicUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  // ── Upload a new photo and make it the customer's profile photo ──
  // Order matters:
  //   1. upload the NEW file (under a new name, so the browser never shows a
  //      stale cached picture);
  //   2. save its path on the profile and CHECK that the profile really
  //      changed (a blocked update does not raise an error by itself);
  //   3. only then delete the OLD file.
  // If step 2 fails, the new file is removed again, so nothing is left behind
  // and the customer keeps the photo they had.
  // Returns the new path.
  Future<String> uploadAndSave({
    required PlatformFile file,
    required String? previousPath,
  }) async {
    final String? problem = check(file);
    if (problem != null) throw ProfilePhotoException(problem);

    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ProfilePhotoException('Please sign in again to change your photo.');
    }

    final Uint8List bytes = file.bytes!;
    final String type = detectType(bytes)!;
    final String path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$type';

    try {
      await _supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentTypeFor(type), upsert: false),
          );
    } on StorageException catch (error) {
      throw ProfilePhotoException(_friendlyStorageError(error));
    } catch (_) {
      throw const ProfilePhotoException(
        'The photo could not be uploaded. Please check your connection and try again.',
      );
    }

    try {
      final List<dynamic> updated = await _supabase
          .from('users')
          .update({'avatar_path': path})
          .eq('id', user.id)
          .select('avatar_path');

      if (updated.isEmpty) {
        throw const ProfilePhotoException('profile not updated');
      }
    } catch (_) {
      await _deleteQuietly(path);
      throw const ProfilePhotoException(
        'The photo was uploaded, but your profile could not be updated. Please try again.',
      );
    }

    if (previousPath != null && previousPath != path) {
      await _deleteQuietly(previousPath);
    }
    return path;
  }

  // ── Remove the photo ────────────────────────────────────────────
  // The profile is cleared FIRST (and checked), then the file is deleted, so
  // the customer is never left pointing at a file that no longer exists.
  Future<void> remove({required String path}) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ProfilePhotoException('Please sign in again to change your photo.');
    }

    try {
      final List<dynamic> updated = await _supabase
          .from('users')
          .update({'avatar_path': null})
          .eq('id', user.id)
          .select('id');

      if (updated.isEmpty) {
        throw const ProfilePhotoException('profile not updated');
      }
    } catch (_) {
      throw const ProfilePhotoException('Your photo could not be removed. Please try again.');
    }

    await _deleteQuietly(path);
  }

  // Deletes a file, but ONLY inside the signed-in customer's own folder, and
  // never makes the caller fail: a leftover file is harmless, a failed
  // upload or removal is not.
  Future<void> _deleteQuietly(String path) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null || !path.startsWith('${user.id}/')) return;

    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (_) {
      // Ignored on purpose (see above).
    }
  }

  String _friendlyStorageError(StorageException error) {
    final String text = error.message.toLowerCase();
    final String code = error.statusCode ?? '';

    if (code == '413' || text.contains('too large') || text.contains('exceeded')) {
      return 'That photo is larger than 2 MB. Please choose a smaller one.';
    }
    if (text.contains('mime') || text.contains('not supported')) {
      return 'Please choose a JPG, PNG or WebP photo.';
    }
    if (code == '401' || code == '403' || text.contains('row-level security')) {
      return 'You don\'t have permission to change this photo. Please sign in again.';
    }
    return 'The photo could not be uploaded. Please try again.';
  }
}