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

      // A brand-new banner that's already Active is live to customers
      // immediately — notify them the same way a new promo would be
      // announced. Banners created as Draft/Inactive stay silent until
      // they're actually switched on (see updateBanner below).
      if (status == 'Active') {
        await _notifyCustomersBannerActive(
          bannerId: inserted['banner_id'] as int,
        );
      }

      return null;
    } catch (error) {
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
      // Fetch the current status BEFORE updating, so we can tell
      // whether this call is actually the moment the banner turns
      // on (e.g. Draft -> Active) versus just editing an already-
      // Active banner's image, or leaving it Inactive. Customers
      // should only be notified on that first transition, not on
      // every subsequent edit while it stays Active.
      final existing = await _supabase
          .from(_table)
          .select('status, banner_image_url')
          .eq('banner_id', bannerId)
          .maybeSingle();
      final String? previousStatus = existing?['status'] as String?;
      final String? previousImageUrl = existing?['banner_image_url'] as String?;

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

      // Old image is now orphaned in storage if it was replaced — clean it
      // up the same best-effort way deleteBanner() does.
      if (newImageBytes != null && previousImageUrl != null) {
        try {
          final Uri uri = Uri.parse(previousImageUrl);
          final int bucketIndex = uri.pathSegments.indexOf(_bucket);
          if (bucketIndex != -1 && bucketIndex < uri.pathSegments.length - 1) {
            final String objectPath =
                uri.pathSegments.sublist(bucketIndex + 1).join('/');
            await _supabase.storage.from(_bucket).remove([objectPath]);
          }
        } catch (storageError) {
        }
      }

      await _activityLog.log(
        action: 'Updated promotion banner #$bannerId',
        affectedModule: AffectedModule.promotions,
        targetId: bannerId.toString(),
        metadata: {'status': status},
      );

      if (status == 'Active' && previousStatus != 'Active') {
        await _notifyCustomersBannerActive(bannerId: bannerId);
      }

      return null;
    } catch (error) {
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
      }

      await _activityLog.log(
        action: 'Deleted promotion banner #$bannerId',
        affectedModule: AffectedModule.promotions,
        targetId: bannerId.toString(),
      );

      return null;
    } catch (error) {
      return error.toString();
    }
  }

  // ==========================================
  // NOTIFY CUSTOMERS — BANNER NOW ACTIVE
  // Fires when a banner transitions into 'Active' (either created
  // that way, or flipped on from another status). Non-critical —
  // a notification failure must never block the actual banner
  // create/update, which has already succeeded by this point.
  // ==========================================
  Future<void> _notifyCustomersBannerActive({
    required int bannerId,
  }) async {
    try {
      final customers = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'Customer');

      if ((customers as List).isEmpty) return;

      final rows = customers
          .map((u) => {
                'customer_id': u['id'],
                'type': 'promotion',
                'title': 'New promo just dropped',
                'body':
                    "Check out our latest deal — tap to see what's new.",
                'recipient_role': 'customer',
              })
          .toList();

      await _supabase.from('notifications').insert(rows); // NO .select() !
    } catch (error) {
    }
  }
}