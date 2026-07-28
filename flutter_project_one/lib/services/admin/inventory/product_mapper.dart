import '../../../models/product.dart';

class ProductMapper {
  static Product? parseProduct(Map<String, dynamic> data) {
    try {
      // ── Brand ──
      final String brandName =
          (data['brand']?['brand_name'] as String?) ?? '';

      // ── Category ──
      final String categoryName =
          (data['category']?['category_name'] as String?) ?? '';

      // ── Description ──
      final String description =
          (data['description'] as String?) ?? '';

      // ── Archived date ──
      String? archivedDate;
      if (data['archived_at'] != null) {
        try {
          final DateTime dt =
              DateTime.parse(data['archived_at'] as String);
          archivedDate =
              '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
        } catch (_) {
          archivedDate = null;
        }
      }

      // ── Variants ──
      // Each raw variant = one product_variant row.
      // Sizes are children — we never flatten here.
      final List<dynamic> rawVariants =
          (data['product_variant'] as List<dynamic>?) ?? [];

      final List<ProductVariant> variants = [];

      for (final rawVariant in rawVariants) {
        final Map<String, dynamic> vd =
            rawVariant as Map<String, dynamic>;

        // ── Images ──
        final List<dynamic> rawImages =
            (vd['product_image'] as List<dynamic>?) ?? [];

        final List<String> imageUrls = [];
        final List<ProductImage> images = []; // NEW
        String? primaryImageUrl;

        for (final rawImage in rawImages) {
          final Map<String, dynamic> img =
              rawImage as Map<String, dynamic>;
          final String? url = img['image_url'] as String?;
          if (url == null || url.isEmpty) continue;

          imageUrls.add(url);
          if (img['is_primary'] == true) primaryImageUrl = url;

          // NEW — carry the real image_id through
          final int? imageId = img['image_id'] as int?;
          if (imageId != null) {
            images.add(ProductImage(
              imageId: imageId,
              imageUrl: url,
              isPrimary: img['is_primary'] == true,
            ));
          }
        }

        // Fallback: first image becomes primary
        if (primaryImageUrl == null && imageUrls.isNotEmpty) {
          primaryImageUrl = imageUrls.first;
        }

        // ── Sizes ──
        // Build SizeEntry list. An empty list is fine — the variant
        // will still be created, so products never go missing.
        final List<dynamic> rawSizes =
            (vd['product_variant_size'] as List<dynamic>?) ?? [];

        final List<SizeEntry> sizes = rawSizes.map((rawSize) {
          final Map<String, dynamic> sd =
              rawSize as Map<String, dynamic>;
          return SizeEntry(
            sizeId: sd['size_id'] as int?,
            size: (sd['size'] as String?) ?? '',
            stockQty: (sd['stock_quantity'] as int?) ?? 0,
            reservedQty: (sd['reserved_quantity'] as int?) ?? 0,
          );
        }).toList();

        variants.add(ProductVariant(
          variantId: vd['variant_id'] as int?,
          color: (vd['color_name'] as String?) ?? '',
          costPrice:
              (vd['cost_price'] as num?)?.toDouble() ?? 0,
          retailPrice:
              (vd['retail_price'] as num?)?.toDouble() ?? 0,
          sizes: sizes,
          imageUrls: imageUrls,
          primaryImageUrl: primaryImageUrl,
          images: images, // NEW
        ));
      }

      return Product(
        productId: data['product_id'].toString(),
        productName:
            (data['product_name'] as String?) ?? '',
        brand: brandName,
        category: categoryName,
        description: description,
        variants: variants,
        archivedDate: archivedDate,
      );
    } catch (error) {
      print('ProductMapper.parseProduct error: $error');
      return null;
    }
  }
}