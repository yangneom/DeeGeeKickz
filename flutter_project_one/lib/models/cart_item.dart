class CartItem {
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final String size;
  final int? sizeId;
  final double retailPrice;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.size,
    this.sizeId,
    required this.retailPrice,
    this.quantity = 1,
  });

  double get subtotal => retailPrice * quantity;
}