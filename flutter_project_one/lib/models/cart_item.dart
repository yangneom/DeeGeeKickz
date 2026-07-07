class CartItem {
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final String size;
  final int? sizeId;

  // Price actually charged (after admin discount, if any).
  final double retailPrice;

  // Undiscounted price — same as retailPrice when there's no
  // active discount. Used to show "was ₱X" and compute savings
  // on the receipt.
  final double originalPrice;

  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.size,
    this.sizeId,
    required this.retailPrice,
    double? originalPrice,
    this.quantity = 1,
  }) : originalPrice = originalPrice ?? retailPrice;

  double get subtotal => retailPrice * quantity;

  bool get hasDiscount => originalPrice > retailPrice;

  double get savings => hasDiscount ? (originalPrice - retailPrice) * quantity : 0;
}