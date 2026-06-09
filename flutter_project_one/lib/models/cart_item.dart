class CartItem {
  final String productId;
  final String productName;
  final String color;
  final String size;
  final double retailPrice;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.color,
    required this.size,
    required this.retailPrice,
    this.quantity = 1,
  });

  double get subtotal => retailPrice * quantity;
}