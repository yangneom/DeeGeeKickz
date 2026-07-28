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
      print('fetchProducts error: $error');
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
      print('fetchBrands error: $error');
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
      print('fetchCategories error: $error');
      return [];
    }
  }

  // ==========================================
  // ADD PRODUCT
  // ==========================================
  Future<String?> addProduct({
    required String productName,
    required String brandName,
    required String categoryName,
    required String description,
    required List<Map<String, dynamic>> variants,
  }) async {
    try {
      final brand = await _supabase
          .from('brand')
          .select('brand_id')
          .eq('brand_name', brandName)
          .single();

      final category = await _supabase
          .from('category')
          .select('category_id')
          .eq('category_name', categoryName)
          .single();

      final int brandId = brand['brand_id'];
      final int categoryId = category['category_id'];

      final product = await _supabase
          .from('product')
          .insert({
            'product_name': productName,
            'brand_id': brandId,
            'category_id': categoryId,
            'description': description,
            'is_archived': false,
          })
          .select('product_id')
          .single();

      final int productId = product['product_id'];

      for (final variant in variants) {
        final variantResult = await _supabase
            .from('product_variant')
            .insert({
              'product_id': productId,
              'color_name': variant['colorName'],
              'cost_price': variant['costPrice'],
              'retail_price': variant['retailPrice'],
            })
            .select('variant_id')
            .single();

        final int variantId = variantResult['variant_id'];

        for (final sizeRow in variant['sizeRows']) {
          await _supabase
              .from('product_variant_size')
              .insert({
                'variant_id': variantId,
                'size': sizeRow['size'],
                'stock_quantity': sizeRow['stockQty'],
                'reserved_quantity': 0,
              });
        }
      }

      await _activityLog.log(
        action: 'Added new product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId.toString(),
        metadata: {'brand': brandName, 'category': categoryName},
      );

      return null;
    } on PostgrestException catch (error) {
      print('addProduct error: $error');

      if (error.code == '23505' &&
          error.message.contains('product_active_name_unique')) {
        return 'A product named "$productName" already exists. Please choose a different name.';
      }

      return 'Failed to add product. Please try again.';
    } catch (error) {
      print('addProduct error: $error');
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
      final int parsedProductId = int.parse(productId);

      // ── Resolve brand / category IDs ──
      final brand = await _supabase
          .from('brand')
          .select('brand_id')
          .eq('brand_name', brandName)
          .single();

      final category = await _supabase
          .from('category')
          .select('category_id')
          .eq('category_name', categoryName)
          .single();

      final int brandId = brand['brand_id'];
      final int categoryId = category['category_id'];

      // ── Update product row ──
      await _supabase.from('product').update({
        'product_name': productName,
        'brand_id': brandId,
        'category_id': categoryId,
        'description': description,
      }).eq('product_id', parsedProductId);

      // ── Collect submitted variant IDs (non-null only) ──
      final List<int> submittedVariantIds = variants
          .map((v) => v['variantId'] as int?)
          .whereType<int>()
          .toList();

      // ── Delete variants that were removed from the UI ──
      // Fetch current variant IDs for this product
      final List<dynamic> existingVariantRows = await _supabase
          .from('product_variant')
          .select('variant_id')
          .eq('product_id', parsedProductId);

      final List<int> existingVariantIds = existingVariantRows
          .map((r) => r['variant_id'] as int)
          .toList();

      final List<int> variantIdsToDelete = existingVariantIds
          .where((id) => !submittedVariantIds.contains(id))
          .toList();

      if (variantIdsToDelete.isNotEmpty) {
        // Cascade: sizes and images are deleted via FK ON DELETE CASCADE
        // If your DB doesn't have CASCADE, delete children first:
        await _supabase
            .from('product_variant_size')
            .delete()
            .inFilter('variant_id', variantIdsToDelete);

        await _supabase
            .from('product_image')
            .delete()
            .inFilter('variant_id', variantIdsToDelete);

        await _supabase
            .from('product_variant')
            .delete()
            .inFilter('variant_id', variantIdsToDelete);
      }

      // ── Process each submitted variant ──
      for (final variant in variants) {
        final int? variantId = variant['variantId'] as int?;
        final List<dynamic> sizeRows =
            variant['sizeRows'] as List<dynamic>;

        late int resolvedVariantId;

        if (variantId == null) {
          // ── INSERT new variant ──
          final result = await _supabase
              .from('product_variant')
              .insert({
                'product_id': parsedProductId,
                'color_name': variant['colorName'],
                'cost_price': variant['costPrice'],
                'retail_price': variant['retailPrice'],
              })
              .select('variant_id')
              .single();

          resolvedVariantId = result['variant_id'] as int;
        } else {
          // ── UPDATE existing variant ──
          resolvedVariantId = variantId;

          await _supabase.from('product_variant').update({
            'color_name': variant['colorName'],
            'cost_price': variant['costPrice'],
            'retail_price': variant['retailPrice'],
          }).eq('variant_id', resolvedVariantId);
        }

        // ── Collect submitted size IDs ──
        final List<int> submittedSizeIds = sizeRows
            .map((s) => s['sizeId'] as int?)
            .whereType<int>()
            .toList();

        // ── Delete removed size rows ──
        final List<dynamic> existingSizeRows = await _supabase
            .from('product_variant_size')
            .select('size_id')
            .eq('variant_id', resolvedVariantId);

        final List<int> existingSizeIds = existingSizeRows
            .map((r) => r['size_id'] as int)
            .toList();

        final List<int> sizeIdsToDelete = existingSizeIds
            .where((id) => !submittedSizeIds.contains(id))
            .toList();

        if (sizeIdsToDelete.isNotEmpty) {
          await _supabase
              .from('product_variant_size')
              .delete()
              .inFilter('size_id', sizeIdsToDelete);
        }

        // ── Insert or update each size row ──
        for (final sizeRow in sizeRows) {
          final int? sizeId = sizeRow['sizeId'] as int?;

          if (sizeId == null) {
            // ── INSERT new size ──
            await _supabase
                .from('product_variant_size')
                .insert({
                  'variant_id': resolvedVariantId,
                  'size': sizeRow['size'],
                  'stock_quantity': sizeRow['stockQty'],
                  'reserved_quantity': 0,
                });
          } else {
            // ── UPDATE existing size ──
            await _supabase
                .from('product_variant_size')
                .update({
                  'size': sizeRow['size'],
                  'stock_quantity': sizeRow['stockQty'],
                })
                .eq('size_id', sizeId);
          }
        }
      }

      await _activityLog.log(
        action: 'Updated product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId,
      );

     return null;
    } on PostgrestException catch (error) {
      print('updateProduct error: $error');

      if (error.code == '23505' &&
          error.message.contains('product_active_name_unique')) {
        return 'A product named "$productName" already exists. Please choose a different name.';
      }

      return 'Failed to update product. Please try again.';
    } catch (error) {
      print('updateProduct error: $error');
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
      // fetch name first so the log entry reads clearly
      final product = await _supabase
          .from('product')
          .select('product_name')
          .eq('product_id', int.parse(productId))
          .single();

      final productName = product['product_name'] as String? ?? 'Unknown';

      await _supabase.from('product').update({
        'is_archived': true,
        'archived_at': DateTime.now().toIso8601String(),
      }).eq('product_id', int.parse(productId));

      await _activityLog.log(
        action: 'Archived product $productName',
        affectedModule: AffectedModule.inventory,
        targetId: productId,
      );

      return null;
    } catch (error) {
      print('archiveProduct error: $error');
      return error.toString();
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