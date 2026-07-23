import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/order.dart';
import '../../super/activity_log/activity_log_service.dart';
import '../../customer/delivery/lalamove_service.dart';

// ================================================
// ORDER MANAGEMENT SERVICE (Admin)
//
// FIX 1: Use bare join "address" and "users" — the
//         hint syntax !fkey_name is only needed when
//         there are multiple FKs to the same table.
// FIX 2: saveTrackingUrl — persists Lalamove link to
//         orders.tracking_url when admin marks Shipped.
//         (Now mainly a manual-override escape hatch —
//         see markAsShipped for the normal automatic path.)
// FIX 3: updateOrderStatus — COD orders only actually
//         collect cash on delivery. When a COD order is
//         marked 'Completed', payment_status is flipped
//         to 'Paid' at that moment (see PaymentService
//         for why gcash/card don't need this — they're
//         already marked Paid at admin approval).
//
// UPDATE: markAsShipped() — NEW. Replaces the old flow where
//         admin had to manually paste a Lalamove link before
//         marking an order Shipped. This calls Lalamove for
//         real (via LalamoveService -> create-delivery-order),
//         then saves the resulting tracking_url AND
//         lalamove_order_id (needed by the webhook to match
//         future status updates back to this order).
// ================================================

/// Thrown by markAsShipped when the order's address has no
/// coordinates — the UI should tell the admin the customer
/// needs to re-save their address before this order can ship.
class OrderMissingCoordinatesException implements Exception {
  final String message;
  OrderMissingCoordinatesException([
    this.message = 'This order\'s address has no map coordinates yet, '
        'so a courier can\'t be booked. Ask the customer to re-save '
        'their address, or use the manual tracking link field below instead.',
  ]);

  @override
  String toString() => message;
}

class OrderManagementService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();
  final LalamoveService _lalamoveService = LalamoveService();

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
          lalamove_order_id,
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
            landmark,
            lat,
            lng
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
  // Used for every transition EXCEPT the Shipped step, which
  // now goes through markAsShipped() instead (see below).
  // Still accepts trackingUrl for the manual-override path in
  // the admin UI, if the automatic booking ever needs bypassing.
  // ================================================
  Future<void> updateOrderStatus({
    required int    orderId,
    required String status,
    String?         adminNote,
    String?         trackingUrl,
  }) async {

    final Map<String, dynamic> updatePayload = {
      'order_status': status,
    };

    if (trackingUrl != null && trackingUrl.trim().isNotEmpty) {
      updatePayload['tracking_url'] = trackingUrl.trim();
    }

    await _supabase
        .from('orders')
        .update(updatePayload)
        .eq('order_id', orderId);

    // COD orders only actually collect cash on delivery — mark the
    // payment row Paid at the same moment the order is Completed.
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

    String action;
    if (status == 'Cancelled') {
      action = 'Cancelled order #$orderId'
          '${adminNote != null && adminNote.trim().isNotEmpty ? ' (reason: $adminNote)' : ''}';
    } else {
      action = 'Updated order #$orderId status to $status';
    }

    await _activityLog.log(
      action: action,
      affectedModule: AffectedModule.orders,
      targetId: orderId.toString(),
      metadata: {
        'status': status,
        if (adminNote != null) 'admin_note': adminNote,
        if (trackingUrl != null) 'tracking_url': trackingUrl,
      },
    );
  }

  // ================================================
  // MARK AS SHIPPED — books the real Lalamove order
  //
  // Replaces the old "paste a link" step. Calls Lalamove
  // (fresh quotation + order placement, all inside
  // create-delivery-order), then saves the real tracking_url
  // and lalamove_order_id, and moves the order to 'Shipped'.
  //
  // Throws OrderMissingCoordinatesException if the order's
  // address has no lat/lng — UI should catch this and offer
  // the manual-link fallback (updateOrderStatus with
  // trackingUrl) instead of silently failing.
  // ================================================
  Future<void> markAsShipped({
    required Order order,
    String? adminNote,
  }) async {
    if (!order.hasCoordinates) {
      throw OrderMissingCoordinatesException();
    }

    final int orderId = int.parse(order.orderId);

    // 1. Book the real Lalamove delivery order.
    final LalamoveOrderResult result = await _lalamoveService.createDeliveryOrder(
      orderId: orderId,
      dropoffLat: order.lat!,
      dropoffLng: order.lng!,
      dropoffAddressText: order.address,
      recipientName: order.customerName,
      recipientPhone: order.contact,
    );

    // 2. Save the results + move to Shipped.
    await _supabase.from('orders').update({
      'order_status': 'Shipped',
      'tracking_url': result.trackingUrl,
      'lalamove_order_id': result.lalamoveOrderId,
    }).eq('order_id', orderId);

    await _supabase.from('order_progress').insert({
      'order_id':   orderId,
      'status':     'Shipped',
      'admin_note': adminNote,
    });

    await _activityLog.log(
      action: 'Booked Lalamove delivery and marked order #$orderId as Shipped',
      affectedModule: AffectedModule.orders,
      targetId: orderId.toString(),
      metadata: {
        'status': 'Shipped',
        'lalamove_order_id': result.lalamoveOrderId,
        'tracking_url': result.trackingUrl,
        if (adminNote != null) 'admin_note': adminNote,
      },
    );
  }

  // ================================================
  // SAVE TRACKING URL ONLY (manual override / fallback)
  // Kept for the case where an order has no coordinates and
  // markAsShipped() can't run automatically — admin can still
  // paste a link by hand as a fallback.
  // ================================================
  Future<void> saveTrackingUrl({
    required int    orderId,
    required String trackingUrl,
  }) async {
    await _supabase
        .from('orders')
        .update({'tracking_url': trackingUrl.trim()})
        .eq('order_id', orderId);

    await _activityLog.log(
      action: 'Updated tracking link for order #$orderId',
      affectedModule: AffectedModule.orders,
      targetId: orderId.toString(),
    );
  }
}