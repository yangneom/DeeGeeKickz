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
    required this.imageUrl,
    this.quantity = 1,
  });

  double get subtotal => retailPrice * quantity;

  CustomerCartItem copyWith({
    int? cartItemId,
    int? productId,
    String? productName,
    String? brand,
    String? color,
    String? size,
    double? retailPrice,
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
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Builds an item from a Supabase `cart_item` row.
  factory CustomerCartItem.fromJson(Map<String, dynamic> json) {
    return CustomerCartItem(
      cartItemId: json['cart_item_id'] as int?,
      productId: json['product_id'] as int,
      productName: json['product_name_snapshot'] as String? ?? '',
      brand: json['brand_snapshot'] as String? ?? '',
      color: json['color_snapshot'] as String? ?? '',
      size: json['size_snapshot'] as String? ?? '',
      sizeId: json['size_id'] as int?,
      retailPrice: (json['price_snapshot'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url_snapshot'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  /// Serializes for insert/upsert into `cart_item`. `user_id` is added
  /// by the provider (this model doesn't know about auth).
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
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  factory CustomerCartItem.fromLocalJson(Map<String, dynamic> json) {
    return CustomerCartItem(
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      brand: json['brand'] as String,
      color: json['color'] as String,
      size: json['size'] as String,
      sizeId: json['sizeId'] as int?,
      retailPrice: (json['retailPrice'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String,
      quantity: json['quantity'] as int,
    );
  }
}
