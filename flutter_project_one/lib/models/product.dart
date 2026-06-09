// ================================================
// PRODUCT VARIANT
// One specific color + size combination
// ================================================
class ProductVariant {
  // product_variant table
  final int? variantId;

  // product_variant_size table
  final int sizeId;

  // variant details
  final String color;
  final String size;

  // inventory
  final int stockQty;
  final int reservedQty;

  // pricing
  final double costPrice;
  final double retailPrice;

  // images
  final List<String> imageUrls;
  final String? primaryImageUrl;

  ProductVariant({
    this.variantId,
    required this.sizeId,
    required this.color,
    required this.size,
    required this.stockQty,
    this.reservedQty = 0,
    required this.costPrice,
    required this.retailPrice,
    this.imageUrls = const [],
    this.primaryImageUrl,
  });

  // ================================================
  // AVAILABLE STOCK
  // ================================================
  int get availableQty {
    final int available = stockQty - reservedQty;
    return available < 0 ? 0 : available;
  }

  // ================================================
  // FULLY RESERVED
  // ================================================
  bool get isFullyReserved {
    return availableQty == 0 && reservedQty > 0;
  }

  // ================================================
  // STATUS
  // ================================================
  String get status {
    if (isFullyReserved) {
      return 'Reserved';
    }

    if (stockQty == 0) {
      return 'Out of Stock';
    }

    if (availableQty <= 5) {
      return 'Low Stock';
    }

    return 'Available';
  }
}

// ================================================
// PRODUCT
// ================================================
class Product {
  final String productId;
  final String productName;
  final String brand;
  final String category;
  final List<ProductVariant> variants;

  // used only by archived products
  final String? archivedDate;

  Product({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.category,
    required this.variants,
    this.archivedDate,
  });

  // ================================================
  // TOTAL STOCK
  // ================================================
  int get totalStock {
    int total = 0;

    for (final ProductVariant variant in variants) {
      total += variant.stockQty;
    }

    return total;
  }

  // ================================================
  // TOTAL RESERVED
  // ================================================
  int get totalReserved {
    int total = 0;

    for (final ProductVariant variant in variants) {
      total += variant.reservedQty;
    }

    return total;
  }

  // ================================================
  // TOTAL AVAILABLE
  // ================================================
  int get totalAvailable {
    int total = 0;

    for (final ProductVariant variant in variants) {
      total += variant.availableQty;
    }

    return total;
  }

  // ================================================
  // FULLY RESERVED
  // ================================================
  bool get isFullyReserved {
    if (variants.isEmpty) return false;

    for (final ProductVariant variant in variants) {
      if (variant.availableQty > 0) {
        return false;
      }
    }

    return true;
  }

  // ================================================
  // AVERAGE RETAIL PRICE
  // ================================================
  double get averagePrice {
    if (variants.isEmpty) return 0;

    double total = 0;

    for (final ProductVariant variant in variants) {
      total += variant.retailPrice;
    }

    return total / variants.length;
  }
}