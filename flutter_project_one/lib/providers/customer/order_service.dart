import 'package:supabase_flutter/supabase_flutter.dart';
 
import '../../models/customer_cart_item.dart';
import '../../services/customer/payment/payment_service.dart';
 
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

    required String paymentMethod,
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
 
          'payment_method': paymentMethod,
          'order_status': 'Awaiting Payment',
        })
        .select()
        .single();
 
    final int orderId = orderResponse['order_id'];
 
    // ───────────────────────────────────────────
    // 3. Create order items + reserve stock
    // ───────────────────────────────────────────
 
    for (final item in items) {
      await _supabase.from('order_item').insert({
        'order_id': orderId,
 
        // Product reference
        'product_id': item.productId,
 
        // Size relationship — now saved
        'size_id': item.sizeId,
 
        'quantity': item.quantity,
        'unit_price': item.retailPrice,
        'subtotal': item.subtotal,
 
        // Snapshots
        'product_name_snapshot': item.productName,
        'brand_snapshot': item.brand,
        'color_snapshot': item.color,
        'size_snapshot': item.size,
      });
 
      // Reserve stock for this item so it can't be oversold
      // while this order is awaiting payment/approval.
      if (item.sizeId != null) {
        await _reserveStock(sizeId: item.sizeId!, quantity: item.quantity);
      }
    }
 
    // ───────────────────────────────────────────
    // 4. Initial order progress
    // ───────────────────────────────────────────
 
    await _supabase.from('order_progress').insert({
      'order_id': orderId,
      'status': 'Pending',
    });
 
    // ───────────────────────────────────────────
    // 5. Create payment row
    // So admin can see/approve payment status.
    // payment_method is temporary until real
    // PayMongo method is passed in.
    // ───────────────────────────────────────────
    await PaymentService().createPayment(
      orderId: orderId,
      paymentMethod: paymentMethod,
      amountPaid: total,
    );
 
    return orderId;
  }
 
  // ───────────────────────────────────────────
  // RESERVE STOCK
  // Increments reserved_quantity so this stock
  // can't be sold to someone else while this
  // order is pending payment/approval.
  // ───────────────────────────────────────────
  Future<void> _reserveStock({
    required int sizeId,
    required int quantity,
  }) async {
    final row = await _supabase
        .from('product_variant_size')
        .select('reserved_quantity')
        .eq('size_id', sizeId)
        .single();
 
    final int currentReserved =
        (row['reserved_quantity'] as num?)?.toInt() ?? 0;
 
    await _supabase
        .from('product_variant_size')
        .update({'reserved_quantity': currentReserved + quantity})
        .eq('size_id', sizeId);
  }
}