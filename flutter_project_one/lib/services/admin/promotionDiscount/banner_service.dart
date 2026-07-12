import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/promotion_banner_model.dart';
import '../../super/activity_log/activity_log_service.dart';

// ==========================================
// BANNER SERVICE
//
// Same style as InventoryService:
//   - try/catch around every call
//   - print('methodName error: $error') on failure
//   - mutating methods return String? (null = success)
// ==========================================
class BannerService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  static const String _table = 'promotion_banner';
  static const String _bucket = 'promotion-banners';

  // ==========================================
  // FETCH BANNERS
  // All banners, newest upload first — used by
  // the admin BannersTable.
  // ==========================================
  Future<List<PromotionBanner>> fetchBanners() async {
    try {
      final List<dynamic> response = await _supabase
          .from(_table)
          .select()
          .order('upload_date', ascending: false);

      return response
          .map((row) => PromotionBanner.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchBanners error: $error');
      return [];
    }
  }

  // ==========================================
  // FETCH ACTIVE BANNERS
  // Used by the customer homescreen hero carousel.
  // ==========================================
  Future<List<PromotionBanner>> fetchActiveBanners() async {
    try {
      final List<dynamic> response = await _supabase
          .from(_table)
          .select()
          .eq('status', 'Active')
          .order('upload_date', ascending: false);

      return response
          .map((row) => PromotionBanner.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchActiveBanners error: $error');
      return [];
    }
  }

  // ==========================================
  // ADD BANNER
  // Uploads the cropped image bytes to the
  // promotion-banners bucket, then inserts a row.
  // ==========================================
  Future<String?> addBanner({
    required Uint8List imageBytes,
    required String fileExt,
    required String status,
  }) async {
    try {
      final String fileName =
          'banner_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from(_bucket).uploadBinary(
            fileName,
            imageBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final String publicUrl =
          _supabase.storage.from(_bucket).getPublicUrl(fileName);

      final inserted = await _supabase
          .from(_table)
          .insert({
            'banner_image_url': publicUrl,
            'status': status,
          })
          .select('banner_id')
          .single();

      await _activityLog.log(
        action: 'Added new promotion banner',
        affectedModule: AffectedModule.promotions,
        targetId: inserted['banner_id']?.toString(),
        metadata: {'status': status},
      );

      return null;
    } catch (error) {
      print('addBanner error: $error');
      return error.toString();
    }
  }

  // ==========================================
  // UPDATE BANNER
  // If newImageBytes is provided, uploads a fresh
  // image and replaces banner_image_url. Always
  // updates status.
  // ==========================================
  Future<String?> updateBanner({
    required int bannerId,
    Uint8List? newImageBytes,
    String? fileExt,
    required String status,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': status,
      };

      if (newImageBytes != null && fileExt != null) {
        final String fileName =
            'banner_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage.from(_bucket).uploadBinary(
              fileName,
              newImageBytes,
              fileOptions: FileOptions(
                contentType: 'image/$fileExt',
                upsert: false,
              ),
            );

        final String publicUrl =
            _supabase.storage.from(_bucket).getPublicUrl(fileName);

        updateData['banner_image_url'] = publicUrl;
      }

      await _supabase.from(_table).update(updateData).eq('banner_id', bannerId);

      await _activityLog.log(
        action: 'Updated promotion banner #$bannerId',
        affectedModule: AffectedModule.promotions,
        targetId: bannerId.toString(),
        metadata: {'status': status},
      );

      return null;
    } catch (error) {
      print('updateBanner error: $error');
      return error.toString();
    }
  }

  // ==========================================
  // DELETE BANNER
  // Deletes the DB row; best-effort removes the
  // storage object too (won't fail the whole
  // operation if storage delete fails).
  // ==========================================
  Future<String?> deleteBanner({
    required int bannerId,
    required String imageUrl,
  }) async {
    try {
      await _supabase.from(_table).delete().eq('banner_id', bannerId);

      // best-effort storage cleanup
      try {
        final Uri uri = Uri.parse(imageUrl);
        // public URL shape: .../object/public/promotion-banners/<fileName>
        final int bucketIndex = uri.pathSegments.indexOf(_bucket);
        if (bucketIndex != -1 && bucketIndex < uri.pathSegments.length - 1) {
          final String objectPath =
              uri.pathSegments.sublist(bucketIndex + 1).join('/');
          await _supabase.storage.from(_bucket).remove([objectPath]);
        }
      } catch (storageError) {
        print('deleteBanner storage cleanup error: $storageError');
      }

      await _activityLog.log(
        action: 'Deleted promotion banner #$bannerId',
        affectedModule: AffectedModule.promotions,
        targetId: bannerId.toString(),
      );

      return null;
    } catch (error) {
      print('deleteBanner error: $error');
      return error.toString();
    }
  }
}