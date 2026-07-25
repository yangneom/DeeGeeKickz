/// Represents a single item in the CUSTOMER shopping cart.
/// Backed by Supabase `cart_item` table once the user is logged in.
/// Guests hold this purely in memory (Notifier state) until they log in,
/// at which point CustomerCartNotifier pushes them up to Supabase.
class CustomerCartItem {
  /// Supabase row id (cart_item_id). Null until this item has been
  /// persisted to the database (i.e. still guest-only, in-memory).
  final int? cartItemId;

  final int productId;
  final String productName;
  final String brand;
  final String color;
  final String size;
  final int? sizeId;
  final double retailPrice;

  /// The price before any active discount was applied. Equal to
  /// retailPrice when there's no discount. Needed so checkout, order
  /// creation, and admin screens can all show a real "you saved ₱X"
  /// figure instead of the discount being silently baked into
  /// retailPrice with no trace of what it was.
  final double originalPrice;

  final String imageUrl;
  int quantity;

  CustomerCartItem({
    this.cartItemId,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.size,
    this.sizeId,
    required this.retailPrice,
    double? originalPrice,
    required this.imageUrl,
    this.quantity = 1,
  }) : originalPrice = originalPrice ?? retailPrice;

  double get subtotal => retailPrice * quantity;

  /// Per-unit discount amount (0 if there was no discount).
  double get discountPerUnit => originalPrice - retailPrice;

  /// Total discount for this line (per-unit discount × quantity).
  double get discountSubtotal => discountPerUnit * quantity;

  CustomerCartItem copyWith({
    int? cartItemId,
    int? productId,
    String? productName,
    String? brand,
    String? color,
    String? size,
    double? retailPrice,
    double? originalPrice,
    int? sizeId,
    String? imageUrl,
    int? quantity,
  }) {
    return CustomerCartItem(
      cartItemId: cartItemId ?? this.cartItemId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      size: size ?? this.size,
      sizeId: sizeId ?? this.sizeId,
      retailPrice: retailPrice ?? this.retailPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Builds an item from a Supabase `cart_item` row.
  factory CustomerCartItem.fromJson(Map<String, dynamic> json) {
    final double price = (json['price_snapshot'] as num?)?.toDouble() ?? 0.0;
    return CustomerCartItem(
      cartItemId: json['cart_item_id'] as int?,
      productId: json['product_id'] as int,
      productName: json['product_name_snapshot'] as String? ?? '',
      brand: json['brand_snapshot'] as String? ?? '',
      color: json['color_snapshot'] as String? ?? '',
      size: json['size_snapshot'] as String? ?? '',
      sizeId: json['size_id'] as int?,
      retailPrice: price,
      // original_price_snapshot may not exist on rows created before
      // this column was added — fall back to retailPrice (no discount
      // shown) rather than crashing on old cart rows.
      originalPrice:
          (json['original_price_snapshot'] as num?)?.toDouble() ?? price,
      imageUrl: json['image_url_snapshot'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  /// Serializes for insert/upsert into `cart_item`. `user_id` is added
  /// by the provider (this model doesn't know about auth).
  Map<String, dynamic> toJson({required String userId}) {
    return {
      'user_id': userId,
      'product_id': productId,
      'size_id': sizeId,
      'product_name_snapshot': productName,
      'brand_snapshot': brand,
      'color_snapshot': color,
      'size_snapshot': size,
      'price_snapshot': retailPrice,
      'original_price_snapshot': originalPrice,
      'image_url_snapshot': imageUrl,
      'quantity': quantity,
    };
  }

  /// Lightweight serialization for guest carts saved to device storage
  /// (SharedPreferences). No user_id/cart_item_id involved — guests
  /// aren't in the database yet.
  Map<String, dynamic> toLocalJson() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'color': color,
      'size': size,
      'sizeId': sizeId,
      'retailPrice': retailPrice,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  factory CustomerCartItem.fromLocalJson(Map<String, dynamic> json) {
    final double price = (json['retailPrice'] as num).toDouble();
    return CustomerCartItem(
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      brand: json['brand'] as String,
      color: json['color'] as String,
      size: json['size'] as String,
      sizeId: json['sizeId'] as int?,
      retailPrice: price,
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? price,
      imageUrl: json['imageUrl'] as String,
      quantity: json['quantity'] as int,
    );
  }
}