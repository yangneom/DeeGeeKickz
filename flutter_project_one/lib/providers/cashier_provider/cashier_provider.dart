import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cart_item.dart';

final cashierProvider =
    NotifierProvider<CashierNotifier, List<CartItem>>(
      CashierNotifier.new,
    );

class CashierNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  // ==========================================
  // ADD TO CART
  // ==========================================
void addToCart({
      required String productId,
      required String productName,
      required String brand,
      required String color,
      required String size,
      int? sizeId,
      required double retailPrice,
      double? originalPrice,
      required int quantity,
    }) {
    final updatedCart = [...state];

    final existingIndex = updatedCart.indexWhere(
      (item) =>
          item.productId == productId &&
          item.color == color &&
          item.size == size,
    );

    if (existingIndex >= 0) {
      updatedCart[existingIndex].quantity += quantity;
    } else {
      updatedCart.add(
      CartItem(
        productId:   productId,
        productName: productName,
        brand:       brand,
        color:       color,
        size:        size,
        sizeId:      sizeId,
        retailPrice: retailPrice,
        originalPrice: originalPrice,
        quantity:    quantity,
      ),
    );
    }

    state = updatedCart;
  }

  // ==========================================
  // REMOVE ITEM
  // ==========================================
  void removeFromCart(int index) {
    if (index < 0 || index >= state.length) return;

    final updatedCart = [...state];
    updatedCart.removeAt(index);
    state = updatedCart;
  }

  // ==========================================
  // INCREASE QUANTITY
  // ==========================================
  void increaseQuantity(int index) {
    if (index < 0 || index >= state.length) return;

    final updatedCart = [...state];
    updatedCart[index].quantity++;
    state = updatedCart;
  }

  // ==========================================
  // DECREASE QUANTITY
  // ==========================================
  void decreaseQuantity(int index) {
    if (index < 0 || index >= state.length) return;

    final updatedCart = [...state];

    updatedCart[index].quantity--;

    if (updatedCart[index].quantity <= 0) {
      updatedCart.removeAt(index);
    }

    state = updatedCart;
  }

  // ==========================================
  // CLEAR CART
  // ==========================================
  void clearCart() {
    state = [];
  }
}