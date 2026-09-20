import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================
  // UPLOAD IMAGE
  // ==========================================
  Future<String?> uploadImage({
    required int variantId,
    required File imageFile,
    bool isPrimary = false,
  }) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      // Upload to Storage
      await _supabase.storage
          .from('product-images')
          .upload(fileName, imageFile);

      final String imageUrl = _supabase.storage
          .from('product-images')
          .getPublicUrl(fileName);
        try {
          if (isPrimary) {
            await _supabase
                .from('product_image')
                .update({'is_primary': false})
                .eq('variant_id', variantId);
          }

          await _supabase.from('product_image').insert({
            'variant_id': variantId,
            'image_url': imageUrl,
            'is_primary': isPrimary,
          });

          return imageUrl;
        } catch (error) {
          await _supabase.storage
              .from('product-images')
              .remove([fileName]);

          rethrow;
        }
    } catch (error) {
      print('uploadImage error: $error');
      return null;
    }
  }

  // ==========================================
  // GET IMAGES BY VARIANT
  // ==========================================
  Future<List<String>> fetchVariantImages(
    int variantId,
  ) async {
    try {
      final List<dynamic> response = await _supabase
          .from('product_image')
          .select('image_url')
          .eq('variant_id', variantId)
          .order('created_at');

      return response
          .map((e) => e['image_url'] as String)
          .toList();
    } catch (error) {
      return [];
    }
  }

  // ==========================================
  // GET PRIMARY IMAGE
  // ==========================================
  Future<String?> fetchPrimaryImage(
    int variantId,
  ) async {
    try {
      final response = await _supabase
          .from('product_image')
          .select('image_url')
          .eq('variant_id', variantId)
          .eq('is_primary', true)
          .maybeSingle();

      return response?['image_url'];
    } catch (error) {
      return null;
    }
  }

  // ==========================================
  // DELETE IMAGE
  // ==========================================
  Future<String?> deleteImage(
    int imageId,
  ) async {
    try {
      final image = await _supabase
          .from('product_image')
          .select()
          .eq('image_id', imageId)
          .single();

      final String imageUrl = image['image_url'];

          final String bucketPath =
          imageUrl.split('product-images/').last;

                  await _supabase
            .from('product_image')
            .delete()
            .eq('image_id', imageId);

        await _supabase.storage
            .from('product-images')
            .remove([bucketPath]);

      return null;
    } catch (error) {
      return error.toString();
    }
  }
}