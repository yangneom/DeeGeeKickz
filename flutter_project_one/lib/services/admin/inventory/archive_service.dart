import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/product.dart';
import 'product_mapper.dart';

class ArchiveService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    try {
      await _supabase
          .from('product')
          .update({
            'is_archived': false,
            'archived_at': null,
          })
          .eq('product_id', int.parse(productId));
      return null;
    } catch (error) {
      print('restoreProduct error: $error');
      return 'Failed to restore product. Please try again.';
    }
  }

}