import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/product.dart';
import 'product_mapper.dart';
import '../../super/activity_log/activity_log_service.dart';

class ArchiveService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  Future<List<Product>> fetchArchivedProducts() async {
    try {
      final List<dynamic> response = await _supabase
          .from('product')
          .select('''
            product_id,
            product_name,
            is_archived,
            archived_at,
            brand ( brand_name ),
            category ( category_name ),
            product_variant (
              variant_id,
              color_name,
              cost_price,
              retail_price,

              product_image (
                image_id,
                image_url,
                is_primary
              ),

              product_variant_size (
                size_id,
                size,
                stock_quantity,
                reserved_quantity
              )
            )
          ''')
          .eq('is_archived', true)
          .order('archived_at', ascending: false);

      List<Product> products = [];
      for (int i = 0; i < response.length; i++) {
        Product? product =
        ProductMapper.parseProduct(response[i]);
        if (product != null) products.add(product);
      }
      return products;
    } catch (error) {
      print('fetchArchivedProducts error: $error');
      return [];
    }
  }

 Future<String?> restoreProduct({required String productId}) async {
    String productName = 'this product';
    try {
      final product = await _supabase
          .from('product')
          .select('product_name')
          .eq('product_id', int.parse(productId))
          .single();

      productName = product['product_name'] as String? ?? 'Unknown';

      await _supabase
          .from('product')
          .update({
            'is_archived': false,
            'archived_at': null,
          })
          .eq('product_id', int.parse(productId));

      await _activityLog.log(
        action: 'Restored product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId,
      );

      return null;
    } on PostgrestException catch (error) {
      print('restoreProduct error: $error');

      if (error.code == '23505' &&
          error.message.contains('product_active_name_unique')) {
        return 'Can\'t restore "$productName" — an active product with this name already exists. Rename or archive the other one first.';
      }

      return 'Failed to restore product. Please try again.';
    } catch (error) {
      print('restoreProduct error: $error');
      return 'Failed to restore product. Please try again.';
    }
  }

}