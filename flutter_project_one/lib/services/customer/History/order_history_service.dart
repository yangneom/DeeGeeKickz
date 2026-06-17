import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/order.dart';

class OrderHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Order>> getMyOrders() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final ordersResponse = await _supabase
        .from('orders')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    List<Order> orders = [];

    for (final orderRow in ordersResponse) {
      final orderItemsResponse = await _supabase
          .from('order_item')
          .select()
          .eq('order_id', orderRow['order_id']);

      List<OrderItem> items = [];

      for (final item in orderItemsResponse) {
        items.add(
          OrderItem(
            productName: item['product_name_snapshot'] ?? '',
            brand: item['brand_snapshot'] ?? '',
            size: int.tryParse(
                    item['size_snapshot']?.toString() ?? '0') ??
                0,
            quantity: item['quantity'] ?? 0,
            price: (item['unit_price'] ?? 0).toDouble(),
            total: (item['subtotal'] ?? 0).toDouble(),
          ),
        );
      }

      orders.add(
        Order(
          orderId: orderRow['order_id'].toString(),
          customerName: '',
          contact: '',
          landmark: '',
          address: '',
          totalAmount:
              (orderRow['total_amount'] ?? 0).toDouble(),
          paymentMethod:
              orderRow['payment_method'] ?? '',
          paymentStatus: 'Paid',
          orderStatus:
              orderRow['order_status'] ?? 'Pending',
          dateTime:
              orderRow['created_at']?.toString() ?? '',
          items: items,
        ),
      );
    }

    return orders;
  }
}