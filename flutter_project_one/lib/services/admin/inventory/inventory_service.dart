import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/product.dart';
import 'product_mapper.dart';

class InventoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Product>> fetchProducts() async {
    try {
      final List<dynamic> response = await _supabase
          .from('product')
          .select('''
            product_id,
      product_name,
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

        print(response);

      List<Product> products = [];
      for (int i = 0; i < response.length; i++) {
        Product? product =
        ProductMapper.parseProduct(response[i]);
        if (product != null) products.add(product);
      }
      return products;
    } catch (error) {
      print('fetchProducts error: $error');
      return [];
    }
  }

  Future<List<String>> fetchBrands() async {
    try {
      final List<dynamic> response = await _supabase
          .from('brand')
          .select('brand_name')
          .order('brand_name');

      List<String> brands = [];
      for (int i = 0; i < response.length; i++) {
        String? name = response[i]['brand_name'] as String?;
        if (name != null) brands.add(name);
      }
      return brands;
    } catch (error) {
      print('fetchBrands error: $error');
      return [];
    }
  }


  Future<List<String>> fetchCategories() async {
    try {
      final List<dynamic> response = await _supabase
          .from('category')
          .select('category_name')
          .order('category_name');

      List<String> categories = [];
      for (int i = 0; i < response.length; i++) {
        String? name = response[i]['category_name'] as String?;
        if (name != null) categories.add(name);
      }
      return categories;
    } catch (error) {
      print('fetchCategories error: $error');
      return [];
    }
  }

  List<Product> applyFilters({
    required List<Product> allProducts,
    required String searchQuery,
    required String? selectedCategory,
    required String? selectedStatus,
  }) {
    List<Product> results = [];

    for (Product product in allProducts) {
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch =
            product.productName.toLowerCase().contains(searchQuery);
        bool brandMatch =
            product.brand.toLowerCase().contains(searchQuery);
        bool categoryMatch =
            product.category.toLowerCase().contains(searchQuery);
        matchesSearch = nameMatch || brandMatch || categoryMatch;
      }
      if (!matchesSearch) continue;

      bool matchesCategory = true;
      if (selectedCategory != null) {
        matchesCategory = product.category == selectedCategory;
      }
      if (!matchesCategory) continue;

      bool matchesStatus = true;
      if (selectedStatus != null) {
        matchesStatus = false;
        for (ProductVariant variant in product.variants) {
          if (variant.status == selectedStatus) {
            matchesStatus = true;
            break;
          }
        }
      }
      if (!matchesStatus) continue;

      results.add(product);
    }

    return results;
  }

  List<String> getCategories(List<Product> products) {
    List<String> categories = [];
    for (Product product in products) {
      if (!categories.contains(product.category)) {
        categories.add(product.category);
      }
    }
    return categories;
  }

    Future<String?> addProduct({
          required String productName,
          required String brandName,
          required String categoryName,
          required String description,
          required List<Map<String, dynamic>> variants,
        }) async {
          try {
            // --------------------------------------------------
            // FIND BRAND ID
            // --------------------------------------------------
            final brandResult = await _supabase
                .from('brand')
                .select('brand_id')
                .eq('brand_name', brandName)
                .single();

            final int brandId = brandResult['brand_id'];

            // --------------------------------------------------
            // FIND CATEGORY ID
            // --------------------------------------------------
            final categoryResult = await _supabase
                .from('category')
                .select('category_id')
                .eq('category_name', categoryName)
                .single();

            final int categoryId = categoryResult['category_id'];

            // --------------------------------------------------
            // CREATE PRODUCT
            // --------------------------------------------------
            final productResult = await _supabase
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

            final int productId = productResult['product_id'];

            // --------------------------------------------------
            // CREATE VARIANTS
            // --------------------------------------------------
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

              // ------------------------------------------------
              // CREATE SIZES
              // ------------------------------------------------
              final List<dynamic> sizeRows =
                  variant['sizeRows'] as List<dynamic>;

              for (final sizeRow in sizeRows) {
                await _supabase.from('product_variant_size').insert({
                  'variant_id': variantId,
                  'size': sizeRow['size'],
                  'stock_quantity': sizeRow['stockQty'],
                  'reserved_quantity': 0,
                });
              }
            }

            return null;
          } catch (error) {
            print('addProduct error: $error');
            return error.toString();
          }
        }
    // ================================================
  // ARCHIVE PRODUCT
  // ================================================
  Future<String?> archiveProduct({
    required String productId,
  }) async {
    try {
      await _supabase
          .from('product')
          .update({
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
          })
          .eq('product_id', int.parse(productId));

      return null;
    } catch (error) {
      print('archiveProduct error: $error');
      return error.toString();
    }
  }
}