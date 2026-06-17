import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer_cart_item.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<int> createOrder({
    required String userId,

    // Shipping address from checkout
    required String street,
    required String city,
    required String postal,
    required String country,

    required List<CustomerCartItem> items,

    required double subtotal,
    required double shipping,
    required double total,
  }) async {
    // ───────────────────────────────────────────
    // 1. Save shipping address
    // ───────────────────────────────────────────

    final addressResponse = await _supabase
        .from('address')
        .insert({
          'user_id': userId,
          'street': street,
          'city': city,
          'zip_code': postal,
          'landmark': null,
        })
        .select()
        .single();

    final int addressId = addressResponse['address_id'];

    // ───────────────────────────────────────────
    // 2. Create order
    // ───────────────────────────────────────────

    final orderResponse = await _supabase
    .from('orders')
    .insert({
      'user_id': userId,
      'address_id': addressId,

      'subtotal': subtotal,
      'shipping': shipping,
      'total_amount': total,

      'payment_method': 'Online Banking', // temporary
      'order_status': 'Pending',
    })
        .select()
        .single();

    final int orderId = orderResponse['order_id'];

    // ───────────────────────────────────────────
    // 3. Create order items
    // ───────────────────────────────────────────

    for (final item in items) {
      await _supabase.from('order_item').insert({
        'order_id': orderId,

        // Product reference
        'product_id': item.productId,

        // Size relationship later

        'quantity': item.quantity,
        'unit_price': item.retailPrice,
        'subtotal': item.subtotal,

        // Snapshots
        'product_name_snapshot': item.productName,
        'brand_snapshot': item.brand,
        'color_snapshot': item.color,
        'size_snapshot': item.size,
      });
    }

    // ───────────────────────────────────────────
    // 4. Initial order progress
    // ───────────────────────────────────────────

    await _supabase.from('order_progress').insert({
      'order_id': orderId,
      'status': 'Pending',
    });

    return orderId;
  }
}