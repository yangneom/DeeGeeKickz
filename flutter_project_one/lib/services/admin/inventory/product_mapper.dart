import '../../../models/product.dart';

class ProductMapper {
  static Product? parseProduct(
    Map<String, dynamic> data,
  ) {
    try {
      // ================================================
      // BRAND
      // ================================================
      String brandName = '';

      if (data['brand'] != null) {
        brandName =
            data['brand']['brand_name'] as String? ?? '';
      }

      // ================================================
      // CATEGORY
      // ================================================
      String categoryName = '';

      if (data['category'] != null) {
        categoryName =
            data['category']['category_name'] as String? ?? '';
      }

      // ================================================
      // ARCHIVED DATE
      // ================================================
      String? archivedDate;

      if (data['archived_at'] != null) {
        try {
          final DateTime dt = DateTime.parse(
            data['archived_at'] as String,
          );

          archivedDate =
              '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
        } catch (_) {
          archivedDate = null;
        }
      }

      // ================================================
      // VARIANTS
      // ================================================
      List<ProductVariant> variants = [];

      final List<dynamic> rawVariants =
          data['product_variant'] as List<dynamic>? ?? [];

      for (final rawVariant in rawVariants) {
        final Map<String, dynamic> variantData =
            rawVariant as Map<String, dynamic>;

        // ================================================
        // IMAGES
        // ================================================
        final List<dynamic> rawImages =
            variantData['product_image'] as List<dynamic>? ?? [];

        List<String> imageUrls = [];
        String? primaryImageUrl;

        for (final rawImage in rawImages) {
          final Map<String, dynamic> imageData =
              rawImage as Map<String, dynamic>;

          final String? imageUrl =
              imageData['image_url'] as String?;

          if (imageUrl == null || imageUrl.isEmpty) {
            continue;
          }

          imageUrls.add(imageUrl);

          if (imageData['is_primary'] == true) {
            primaryImageUrl = imageUrl;
          }
        }

        // fallback to first image
        if (primaryImageUrl == null &&
            imageUrls.isNotEmpty) {
          primaryImageUrl = imageUrls.first;
        }

        // ================================================
        // SIZES
        // ================================================
        final List<dynamic> rawSizes =
            variantData['product_variant_size']
                    as List<dynamic>? ??
                [];

        for (final rawSize in rawSizes) {
          final Map<String, dynamic> sizeData =
              rawSize as Map<String, dynamic>;

          variants.add(
            ProductVariant(
              // product_variant
              variantId:
                  variantData['variant_id'] as int?,

              // product_variant_size
              sizeId:
                  sizeData['size_id'] as int? ?? 0,

              color:
                  variantData['color_name'] as String? ??
                      '',

              size:
                  sizeData['size'] as String? ?? '',

              stockQty:
                  sizeData['stock_quantity'] as int? ??
                      0,

              reservedQty:
                  sizeData['reserved_quantity']
                          as int? ??
                      0,

              costPrice:
                  (variantData['cost_price'] as num?)
                          ?.toDouble() ??
                      0,

              retailPrice:
                  (variantData['retail_price'] as num?)
                          ?.toDouble() ??
                      0,

              // images
              imageUrls: imageUrls,
              primaryImageUrl: primaryImageUrl,
            ),
          );
        }
      }

      return Product(
        productId: data['product_id'].toString(),
        productName:
            data['product_name'] as String? ?? '',
        brand: brandName,
        category: categoryName,
        variants: variants,
        archivedDate: archivedDate,
      );
    } catch (error) {
      print(
        'ProductMapper.parseProduct error: $error',
      );
      return null;
    }
  }
}