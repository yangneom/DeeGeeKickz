import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/order.dart';

class OrderHistoryService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<List<Order>> getMyOrders() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final ordersResponse =
        await _supabase
            .from('orders')
            .select()
            .eq('user_id', user.id)
            .order(
              'created_at',
              ascending: false,
            );

    List<Order> orders = [];

    for (final orderRow in ordersResponse) {
      final orderId =
          orderRow['order_id'];

      final itemsResponse =
          await _supabase
              .from('order_item')
              .select()
              .eq('order_id', orderId);

      List<OrderItem> items = [];

      for (final itemRow
          in itemsResponse) {
        items.add(
          OrderItem(
            productName:
                itemRow[
                    'product_name_snapshot'] ??
                '',
            brand:
                itemRow[
                    'brand_snapshot'] ??
                '',
            size: int.tryParse(
                    itemRow[
                            'size_snapshot']
                        ?.toString() ??
                        '') ??
                0,
            quantity:
                itemRow['quantity'],
            price:
                (itemRow['unit_price']
                        as num)
                    .toDouble(),
            total:
                (itemRow['subtotal']
                        as num)
                    .toDouble(),
          ),
        );
      }

      orders.add(
        Order(
          orderId:
              orderId.toString(),

          customerName:
              'Customer',

          contact: '',

          landmark: '',

          address: '',

          totalAmount:
              (orderRow[
                          'total_amount']
                      as num)
                  .toDouble(),

          paymentMethod:
              orderRow[
                      'payment_method'] ??
                  '',

          paymentStatus:
              'Paid',

          orderStatus:
              orderRow[
                      'order_status'] ??
                  'Pending',

          dateTime:
              orderRow[
                      'created_at']
                  .toString(),

          items: items,
        ),
      );
    }

    return orders;
  }
}