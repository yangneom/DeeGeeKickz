// ================================================
// SIZE ENTRY
// Represents one row in product_variant_size
// ================================================
class SizeEntry {
  final int? sizeId;
  final String size;
  final int stockQty;
  final int reservedQty;

  SizeEntry({
    this.sizeId,
    required this.size,
    required this.stockQty,
    this.reservedQty = 0,
  });

  // ── Available stock ──
  int get availableQty {
    final int available = stockQty - reservedQty;
    return available < 0 ? 0 : available;
  }

  bool get isFullyReserved => availableQty == 0 && reservedQty > 0;

  String get status {
    if (isFullyReserved) return 'Reserved';
    if (stockQty == 0) return 'Out of Stock';
    if (availableQty <= 5) return 'Low Stock';
    return 'Available';
  }
}

// ================================================
// PRODUCT VARIANT
// One color, with its own sizes + images + pricing
// Maps 1-to-1 with product_variant table row
// ================================================
class ProductVariant {
  final int? variantId;

  final String color;

  final double costPrice;
  final double retailPrice;

  // All sizes belonging to this color variant
  final List<SizeEntry> sizes;

  // Images
  final List<String> imageUrls;
  final String? primaryImageUrl;

  ProductVariant({
    this.variantId,
    required this.color,
    required this.costPrice,
    required this.retailPrice,
    this.sizes = const [],
    this.imageUrls = const [],
    this.primaryImageUrl,
  });

  // ── Aggregate stock across all sizes ──
  int get totalStock =>
      sizes.fold(0, (sum, s) => sum + s.stockQty);

  int get totalReserved =>
      sizes.fold(0, (sum, s) => sum + s.reservedQty);

  int get totalAvailable =>
      sizes.fold(0, (sum, s) => sum + s.availableQty);

  bool get isFullyReserved =>
      sizes.isNotEmpty && sizes.every((s) => s.availableQty == 0);

  // Overall status driven by worst size status
  String get status {
    if (sizes.isEmpty) return 'Out of Stock';
    if (sizes.every((s) => s.stockQty == 0)) return 'Out of Stock';
    if (sizes.any((s) => s.isFullyReserved)) return 'Reserved';
    if (sizes.any((s) => s.availableQty <= 5)) return 'Low Stock';
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
  final String description; // ← was missing
  final List<ProductVariant> variants;
  final String? archivedDate;

  Product({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.category,
    required this.description,
    required this.variants,
    this.archivedDate,
  });

  // ── Aggregate helpers ──
  int get totalStock =>
      variants.fold(0, (sum, v) => sum + v.totalStock);

  int get totalReserved =>
      variants.fold(0, (sum, v) => sum + v.totalReserved);

  int get totalAvailable =>
      variants.fold(0, (sum, v) => sum + v.totalAvailable);

  bool get isFullyReserved =>
      variants.isNotEmpty && variants.every((v) => v.isFullyReserved);

  double get averagePrice {
    if (variants.isEmpty) return 0;
    return variants.fold(0.0, (sum, v) => sum + v.retailPrice) /
        variants.length;
  }
}