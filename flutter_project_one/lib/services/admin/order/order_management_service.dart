import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/order.dart';

// ================================================
// ORDER MANAGEMENT SERVICE (Admin)
//
// FIX 1: Use bare join "address" and "users" — the
//         hint syntax !fkey_name is only needed when
//         there are multiple FKs to the same table.
// FIX 2: saveTrackingUrl — persists Lalamove link to
//         orders.tracking_url when admin marks Shipped.
// FIX 3: updateOrderStatus — COD orders only actually
//         collect cash on delivery. When a COD order is
//         marked 'Completed', payment_status is flipped
//         to 'Paid' at that moment (see PaymentService
//         for why gcash/card don't need this — they're
//         already marked Paid at admin approval).
// ================================================

class OrderManagementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // LOAD ORDERS
  // ================================================
  Future<List<Order>> loadOrders() async {

    // ── Step 1: orders with user + address + items ──
    final List<dynamic> ordersResponse = await _supabase
        .from('orders')
        .select('''
          order_id,
          total_amount,
          payment_method,
          order_status,
          tracking_url,
          created_at,
          user_id,
          address_id,
          users (
            first_name,
            last_name,
            phone
          ),
          address (
            street,
            city,
            zip_code,
            landmark
          ),
          order_item (
            product_name_snapshot,
            brand_snapshot,
            size_snapshot,
            quantity,
            unit_price,
            subtotal
          )
        ''')
        .neq('order_status', 'Awaiting Payment')
        .neq('order_type', 'In-Store')
        .order('created_at', ascending: false);

        // ── Step 2: cancel reasons from order_progress ──
      final List<dynamic> progressResponse = await _supabase
          .from('order_progress')
          .select('order_id, admin_note, status')
          .eq('status', 'Cancelled');

      final Map<int, String?> cancelReasonMap = {};
      for (final dynamic p in progressResponse) {
        final int oid = (p['order_id'] as num).toInt();
        cancelReasonMap[oid] = p['admin_note'] as String?;
      }

    // ── Step 2: payment status by order_id ──
    final List<dynamic> paymentResponse = await _supabase
        .from('payment')
        .select('order_id, payment_status, receipt_url');

    final Map<int, String>  paymentStatusMap = {};
    final Map<int, String?> receiptUrlMap    = {};

    for (final dynamic p in paymentResponse) {
      final int oid         = (p['order_id'] as num).toInt();
      paymentStatusMap[oid] = p['payment_status'] ?? '';
      receiptUrlMap[oid]    = p['receipt_url'] as String?;
    }

    // ── Step 3: merge ──
    final List<Order> orders = ordersResponse.map((dynamic row) {
      final Map<String, dynamic> map = row as Map<String, dynamic>;
      final int orderId = (map['order_id'] as num).toInt();

      return Order.fromMap(
        map,
        paymentStatus: paymentStatusMap[orderId] ?? '',
        receiptUrl:    receiptUrlMap[orderId],
        cancelReason:  cancelReasonMap[orderId],
      );
    }).toList();
    return orders;
  }


  // ================================================
  // UPDATE ORDER STATUS
  // ================================================
  Future<void> updateOrderStatus({
    required int    orderId,
    required String status,
    String?         adminNote,
    String?         trackingUrl,  // NEW — pass when marking Shipped
  }) async {

    // Build update payload
    final Map<String, dynamic> updatePayload = {
      'order_status': status,
    };

    // Save Lalamove link if provided
    if (trackingUrl != null && trackingUrl.trim().isNotEmpty) {
      updatePayload['tracking_url'] = trackingUrl.trim();
    }

    await _supabase
        .from('orders')
        .update(updatePayload)
        .eq('order_id', orderId);

    // COD orders only actually collect cash on delivery — mark the
    // payment row Paid at the same moment the order is Completed.
    // gcash/card orders are already Paid by this point (set during
    // admin approval), so this only ever affects COD.
    if (status == 'Completed') {
      final Map<String, dynamic>? paymentRow = await _supabase
          .from('payment')
          .select('payment_method')
          .eq('order_id', orderId)
          .maybeSingle();

      final String method = (paymentRow?['payment_method'] ?? '').toString();
      if (method.toLowerCase() == 'cod') {
        await _supabase
            .from('payment')
            .update({'payment_status': 'Paid'})
            .eq('order_id', orderId);
      }
    }

    await _supabase.from('order_progress').insert({
      'order_id':   orderId,
      'status':     status,
      'admin_note': adminNote,
    });
  }

  // ================================================
  // SAVE TRACKING URL ONLY
  // Call this if admin wants to save/update the
  // Lalamove link without changing the order status.
  // ================================================
  Future<void> saveTrackingUrl({
    required int    orderId,
    required String trackingUrl,
  }) async {
    await _supabase
        .from('orders')
        .update({'tracking_url': trackingUrl.trim()})
        .eq('order_id', orderId);
  }
}