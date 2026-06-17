import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer_cart_item.dart';

class CustomerCartNotifier
    extends Notifier<List<CustomerCartItem>> {

  @override
  List<CustomerCartItem> build() {
    return [];
  }

  void addItem(CustomerCartItem item) {
    final existingIndex = state.indexWhere(
      (e) =>
          e.productId == item.productId &&
          e.color == item.color &&
          e.size == item.size,
    );

    if (existingIndex != -1) {
      final updated = [...state];

      updated[existingIndex] =
          updated[existingIndex].copyWith(
        quantity:
            updated[existingIndex].quantity +
            item.quantity,
      );

      state = updated;
    } else {
      state = [...state, item];
    }
  }

  void removeItem(int index) {
    final updated = [...state];
    updated.removeAt(index);
    state = updated;
  }

  void increment(int index) {
    final updated = [...state];

    updated[index] =
        updated[index].copyWith(
      quantity:
          updated[index].quantity + 1,
    );

    state = updated;
  }

  void decrement(int index) {
    final updated = [...state];

    if (updated[index].quantity > 1) {
      updated[index] =
          updated[index].copyWith(
        quantity:
            updated[index].quantity - 1,
      );

      state = updated;
    }
  }

  void clearCart() {
    state = [];
  }

  double get subtotal =>
      state.fold(
        0,
        (sum, item) => sum + item.subtotal,
      );

  int get totalItems =>
      state.fold(
        0,
        (sum, item) => sum + item.quantity,
      );
}

final customerCartProvider =
    NotifierProvider<
        CustomerCartNotifier,
        List<CustomerCartItem>>(
  CustomerCartNotifier.new,
);