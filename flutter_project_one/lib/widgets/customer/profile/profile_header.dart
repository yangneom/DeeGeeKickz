import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../models/customer_account.dart';
import '../../../services/customer/profile/profile_photo_service.dart';
import '../../common/dialog/app_toast.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../common/forms/auth_form_fields.dart' show AuthFormError;

// What the customer chose to do with their photo.
enum _PhotoAction { view, change, remove }

/// Profile avatar, display name, and membership tier badge.
/// Sits above the section cards on [ProfileScreen].
///
/// The photo is clickable:
///   - the picture itself opens a large viewer (or, if there is no photo yet,
///     the upload window)
///   - the pencil opens View / Change / Remove (or the upload window)
/// The viewer closes with its Close button, a click outside, or Escape.
class ProfileHeader extends StatefulWidget {
  final CustomerAccount account;

  const ProfileHeader({super.key, required this.account});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final ProfilePhotoService _photos = ProfilePhotoService();

  // Kept here so the picture changes the moment an upload succeeds, without
  // reloading the whole profile page.
  String? _avatarPath;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.account.avatarPath;
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.avatarPath != widget.account.avatarPath) {
      _avatarPath = widget.account.avatarPath;
    }
  }

  bool get _hasPhoto => _avatarPath != null && _avatarPath!.isNotEmpty;
  String? get _photoUrl => _photos.publicUrl(_avatarPath);

  // ── The picture itself ────────────────────────────────────────
  Future<void> _onAvatarTap() async {
    if (_removing) return;
    if (!_hasPhoto) {
      await _openUpload();
      return;
    }
    await _openViewer();
  }

  Future<void> _handleAction(_PhotoAction action) async {
    switch (action) {
      case _PhotoAction.view:
        await _openViewer();
        break;
      case _PhotoAction.change:
        await _openUpload();
        break;
      case _PhotoAction.remove:
        await _confirmRemove();
        break;
    }
  }

  Future<void> _openViewer() async {
    final String? url = _photoUrl;
    if (url == null) return;

    final _PhotoAction? action = await showDialog<_PhotoAction>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _PhotoViewerDialog(url: url),
    );

    if (!mounted || action == null) return;
    await _handleAction(action);
  }

  Future<void> _openUpload() async {
    final String? newPath = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _PhotoUploadDialog(
        service: _photos,
        previousPath: _avatarPath,
      ),
    );

    if (newPath == null || !mounted) return;

    setState(() => _avatarPath = newPath);
    AppToast.success(
      context,
      'Your profile photo was updated.',
      title: 'Photo saved',
    );
  }

  Future<void> _confirmRemove() async {
    final String? path = _avatarPath;
    if (path == null || path.isEmpty || _removing) return;

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove photo?',
      message: 'Your profile photo will be deleted and the default avatar '
          'will be shown instead.',
      confirmLabel: 'Remove',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removing = true);
    try {
      await _photos.remove(path: path);
      if (!mounted) return;
      setState(() {
        _avatarPath = null;
        _removing = false;
      });
      AppToast.success(
        context,
        'Your profile photo was removed.',
        title: 'Photo removed',
      );
    } on ProfilePhotoException catch (error) {
      if (!mounted) return;
      setState(() => _removing = false);
      AppToast.error(context, error.message, title: 'Photo not removed');
    } catch (_) {
      if (!mounted) return;
      setState(() => _removing = false);
      AppToast.error(
        context,
        'Your photo could not be removed. Please try again.',
        title: 'Photo not removed',
      );
    }
  }

  // The default avatar, shown when there is no photo or it fails to load.
  static const Widget _defaultAvatar = Center(
    child: Icon(
      Icons.person_outline,
      size: 56,
      color: Color(0xFF656464),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;
    final double size = isDesktop ? 160.0 : 128.0;
    final String? url = _photoUrl;

    return Column(
      children: [
        // ── Avatar with edit button ──────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The picture (or the default avatar)
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE), // surface-container
                      border: Border.all(
                        color: const Color(0xFFCFC4C5), // outline-variant
                        width: 1,
                      ),
                    ),
                    child: (_hasPhoto && url != null)
                        ? Image.network(
                            url,
                            key: ValueKey(url),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => _defaultAvatar,
                          )
                        : _defaultAvatar,
                  ),

                  // The whole picture is the button: hand cursor and a soft
                  // darkening on hover, keyboard-focusable, and named for
                  // screen readers.
                  Positioned.fill(
                    child: Semantics(
                      button: true,
                      label: _hasPhoto ? 'View profile picture' : 'Add profile picture',
                      child: Tooltip(
                        message: _hasPhoto ? 'View profile picture' : 'Add profile picture',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _removing ? null : _onAvatarTap,
                            hoverColor: Colors.black.withOpacity(0.08),
                            focusColor: Colors.black.withOpacity(0.10),
                            splashColor: Colors.black.withOpacity(0.12),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Shown while a photo is being removed
                  if (_removing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withOpacity(0.75),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Edit button — bottom-right corner
            Positioned(
              bottom: 0,
              right: 0,
              child: _hasPhoto ? _buildEditMenu() : _buildAddButton(),
            ),
          ],
        ),

        const SizedBox(height: 16), // mb-md

        // ── Display Name ─────────────────────────────────────────
        Text(
          widget.account.fullName.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: MediaQuery.of(context).size.width >= 768 ? 32 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 4),

        // ── Membership tier ──────────────────────────────────────
        Text(
          'PERFORMANCE ELITE MEMBER',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: Color(0xFF656464), // on-secondary-container
          ),
        ),
      ],
    );
  }

  // The pencil's look, unchanged: black square, white pencil.
  Widget _pencilBox() {
    return Container(
      width: 36,
      height: 36,
      color: Colors.black, // bg-primary
      child: const Icon(
        Icons.edit,
        size: 18,
        color: Colors.white, // on-primary
      ),
    );
  }

  // No photo yet: the pencil goes straight to the upload window.
  Widget _buildAddButton() {
    return Semantics(
      button: true,
      label: 'Add profile photo',
      child: Tooltip(
        message: 'Add profile photo',
        child: InkWell(
          onTap: _removing ? null : _openUpload,
          child: _pencilBox(),
        ),
      ),
    );
  }

  // Has a photo: the pencil opens View / Change / Remove.
  Widget _buildEditMenu() {
    return Semantics(
      button: true,
      label: 'Edit profile photo',
      child: PopupMenuButton<_PhotoAction>(
        tooltip: 'Edit profile photo',
        enabled: !_removing,
        padding: EdgeInsets.zero,
        color: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        onSelected: _handleAction,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _PhotoAction.view,
            child: Text('View photo'),
          ),
          PopupMenuItem(
            value: _PhotoAction.change,
            child: Text('Change photo'),
          ),
          PopupMenuItem(
            value: _PhotoAction.remove,
            child: Text('Remove photo'),
          ),
        ],
        child: _pencilBox(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LARGE VIEWER
//
// Shows the whole photo (never cropped) on any screen: it is fitted inside
// the window with BoxFit.contain, and can be pinched or scrolled to zoom.
// Closes with the Close button, a click outside the picture, or Escape (the
// dialog handles Escape itself; the Close button takes focus first so the key
// works straight away).
// ═══════════════════════════════════════════════════════════════════
class _PhotoViewerDialog extends StatelessWidget {
  final String url;

  const _PhotoViewerDialog({required this.url});

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(screen.width - 32, 900),
          maxHeight: screen.height - 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                autofocus: true,
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Flexible(
              child: Semantics(
                label: 'Profile picture, enlarged',
                image: true,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    key: ValueKey(url),
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 40, color: Colors.white70),
                            SizedBox(height: 8),
                            Text(
                              'We couldn\'t load this photo.',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(_PhotoAction.change),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Change photo'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(_PhotoAction.remove),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove photo'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// UPLOAD WINDOW
//
//   1. Choose a photo (JPG, PNG or WebP, up to 2 MB). It is checked straight
//      away, by its real contents and not only its name.
//   2. A preview is shown. Nothing is uploaded yet.
//   3. Cancel, or Save photo. While saving, everything is switched off, so it
//      cannot be sent twice, and the window cannot be closed mid-upload.
//   4. A failure is shown inside the window and the customer's current photo
//      is left exactly as it was.
// Closes with the new photo's path, or with nothing on Cancel.
// ═══════════════════════════════════════════════════════════════════
class _PhotoUploadDialog extends StatefulWidget {
  final ProfilePhotoService service;
  final String? previousPath;

  const _PhotoUploadDialog({
    required this.service,
    required this.previousPath,
  });

  @override
  State<_PhotoUploadDialog> createState() => _PhotoUploadDialogState();
}

class _PhotoUploadDialogState extends State<_PhotoUploadDialog> {
  PlatformFile? _file;
  String? _error;
  bool _picking = false;
  bool _saving = false;

  Future<void> _choose() async {
    if (_picking || _saving) return;

    setState(() {
      _picking = true;
      _error = null;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ProfilePhotoService.pickerExtensions,
        withData: true, // the bytes are needed on the web
      );
      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }

      final PlatformFile picked = result.files.first;
      final String? problem = ProfilePhotoService.check(picked);

      setState(() {
        _picking = false;
        if (problem != null) {
          // Keep any earlier valid choice; just explain this one.
          _error = problem;
        } else {
          _file = picked;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'We couldn\'t open your files. Please try again.';
      });
    }
  }

  Future<void> _save() async {
    final PlatformFile? file = _file;
    if (file == null || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final String path = await widget.service.uploadAndSave(
        file: file,
        previousPath: widget.previousPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } on ProfilePhotoException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final double width = math.min(440.0, MediaQuery.of(context).size.width - 32);
    final double previewSize = math.min(220.0, width - 48);
    final PlatformFile? file = _file;

    return PopScope(
      // No closing the window (back button) while the upload is running.
      canPop: !_saving,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROFILE PHOTO',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'JPG, PNG or WebP, up to 2 MB.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF656464),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Preview ──
                Center(
                  child: Container(
                    width: previewSize,
                    height: previewSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      border: Border.all(color: const Color(0xFFCFC4C5)),
                    ),
                    child: (file != null && file.bytes != null)
                        ? Image.memory(
                            file.bytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 40, color: Color(0xFF9CA3AF)),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.person_outline,
                                size: 56, color: Color(0xFF656464)),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                if (file != null)
                  Center(
                    child: Text(
                      '${file.name}  ·  ${_formatSize(file.size)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF656464),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Text(
                      'No photo chosen yet.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF656464),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                Center(
                  child: OutlinedButton.icon(
                    onPressed: (_picking || _saving) ? null : _choose,
                    icon: _picking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(file == null ? 'Choose photo' : 'Choose a different photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthFormError(message: _error!),
                ],

                const SizedBox(height: 24),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final Widget cancel = OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Cancel'),
                    );

                    final Widget save = ElevatedButton(
                      // Off until a valid photo is chosen, and while saving.
                      onPressed: (file == null || _saving) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _saving ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                        minimumSize: const Size(0, 48),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save photo',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                    );

                    if (constraints.maxWidth < 320) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [save, const SizedBox(height: 10), cancel],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: 12),
                        Expanded(child: save),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}