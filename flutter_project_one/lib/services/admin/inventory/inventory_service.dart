import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/product.dart';
import 'product_mapper.dart';
import '../../super/activity_log/activity_log_service.dart';

class InventoryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  // ==========================================
  // FETCH PRODUCTS
  // ==========================================
  Future<List<Product>> fetchProducts() async {
    try {
      final List<dynamic> response = await _supabase
          .from('product')
          .select('''
            product_id,
            product_name,
            description,
            is_archived,
            archived_at,

            brand (
              brand_name
            ),

            category (
              category_name
            ),

            product_variant (
              variant_id,
              color_name,
              cost_price,
              retail_price,
              ar_effect_url,


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
          .eq('is_archived', false)
          .order('product_id');

      final List<Product> products = [];
      for (final item in response) {
        final Product? product =
            ProductMapper.parseProduct(item);
        if (product != null) products.add(product);
      }
      return products;
    } catch (error) {
      return [];
    }
  }

  // ==========================================
  // FETCH BRANDS
  // ==========================================
  Future<List<String>> fetchBrands() async {
    try {
      final response = await _supabase
          .from('brand')
          .select('brand_name')
          .order('brand_name');
      return response
          .map<String>((e) => e['brand_name'] as String)
          .toList();
    } catch (error) {
      return [];
    }
  }

  // ==========================================
  // FETCH CATEGORIES
  // ==========================================
  Future<List<String>> fetchCategories() async {
    try {
      final response = await _supabase
          .from('category')
          .select('category_name')
          .order('category_name');
      return response
          .map<String>((e) => e['category_name'] as String)
          .toList();
    } catch (error) {
      return [];
    }
  }

    Future<String?> addProduct({
    required String productName,
    required String brandName,
    required String categoryName,
    required String description,
    required List<Map<String, dynamic>> variants,
  }) async {
    try {
      final dynamic result = await _supabase.rpc('add_product_with_variants', params: {
        'p_product_name': productName,
        'p_brand_name': brandName,
        'p_category_name': categoryName,
        'p_description': description,
        'p_variants': variants,
      });

      final int productId = result as int;

      await _activityLog.log(
        action: 'Added new product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId.toString(),
        metadata: {'brand': brandName, 'category': categoryName},
      );

      try {
        await _supabase.rpc('notify_customers_new_product', params: {
          'p_product_id': productId,
        });
      } catch (notifyError) {
      }

      return null;
    } on PostgrestException catch (error) {

      if (error.code == '23505' &&
          error.message.contains('product_active_name_unique')) {
        return 'A product named "$productName" already exists. Please choose a different name.';
      }
      if (error.code == '22001') {
        return 'One of the fields you entered is too long. Please shorten it and try again.';
      }
      if (error.message.contains('not found')) {
        return error.message;
      }

      return 'Failed to add product. Please try again.';
    } catch (error) {
      return 'Failed to add product. Please try again.';
    }
  }

  // ==========================================
  // UPDATE PRODUCT
  //
  // variants list shape (per item):
  // {
  //   'variantId': int?,          // null = new variant
  //   'colorName': String,
  //   'costPrice': double,
  //   'retailPrice': double,
  //   'sizeRows': [
  //     { 'sizeId': int?, 'size': String, 'stockQty': int }
  //     // sizeId null = new size row
  //   ],
  // }
  //
  // Handles:
  //   • Update existing variants
  //   • Insert new variants (variantId == null)
  //   • Delete removed variants
  //   • Update existing sizes
  //   • Insert new sizes (sizeId == null)
  //   • Delete removed sizes
  // ==========================================
  Future<String?> updateProduct({
    required String productId,
    required String productName,
    required String brandName,
    required String categoryName,
    required String description,
    required List<Map<String, dynamic>> variants,
  }) async {
    try {
      await _supabase.rpc('update_product_with_variants', params: {
        'p_product_id': int.parse(productId),
        'p_product_name': productName,
        'p_brand_name': brandName,
        'p_category_name': categoryName,
        'p_description': description,
        'p_variants': variants,
      });

      await _activityLog.log(
        action: 'Updated product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId,
      );

      return null;
    } on PostgrestException catch (error) {

      if (error.code == '23505' &&
          error.message.contains('product_active_name_unique')) {
        return 'A product named "$productName" already exists. Please choose a different name.';
      }
      if (error.code == '22001') {
        return 'One of the fields you entered is too long. Please shorten it and try again.';
      }
      if (error.message.contains('not found')) {
        return error.message;
      }

      return 'Failed to update product. Please try again.';
    } catch (error) {
      return 'Failed to update product. Please try again.';
    }
  }
  // ==========================================
  // ARCHIVE PRODUCT
  // ==========================================
  Future<String?> archiveProduct({
    required String productId,
  }) async {
    try {
      final product = await _supabase
          .from('product')
          .select('product_name')
          .eq('product_id', int.parse(productId))
          .single();

      final productName = product['product_name'] as String? ?? 'Unknown';

      // AUDIT FIX: was a plain, unprotected client-side .update() —
      // genuinely nothing stopped archiving a product with real,
      // active orders still referencing it, and nothing prevented a
      // direct client call bypassing any Flutter-side check. Now a
      // genuine SECURITY DEFINER RPC, checking real pending orders
      // server-side, the actual authority here — not the UI.
      await _supabase.rpc('archive_product_if_no_pending_orders', params: {
        'p_product_id': int.parse(productId),
      });

      await _activityLog.log(
        action: 'Archived product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId,
      );

      return null;
    } on PostgrestException catch (error) {
      if (error.code == 'P1007') {
        return error.message;
      }
      return 'Failed to archive product. Please try again.';
    } catch (error) {
      return 'Failed to archive product. Please try again.';
    }
  }

  // ==========================================
  // FILTERS
  // ==========================================
  List<Product> applyFilters({
    required List<Product> allProducts,
    required String searchQuery,
    required String? selectedCategory,
    required String? selectedStatus,
  }) {
    return allProducts.where((product) {
      final String query = searchQuery.toLowerCase();

      final bool searchMatch = query.isEmpty ||
          product.productName.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);

      final bool categoryMatch =
          selectedCategory == null ||
          product.category == selectedCategory;

      // Status is now on ProductVariant, not SizeEntry
      final bool statusMatch =
          selectedStatus == null ||
          product.variants.any((v) => v.status == selectedStatus);

      return searchMatch && categoryMatch && statusMatch;
    }).toList();
  }

  // ==========================================
  // GET UNIQUE CATEGORIES
  // ==========================================
  List<String> getCategories(List<Product> products) {
    return products.map((e) => e.category).toSet().toList();
  }
}