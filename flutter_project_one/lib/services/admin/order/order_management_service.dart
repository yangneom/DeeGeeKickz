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
//
// UPDATE: loadOrders() now also selects subtotal, shipping, and
//         discount_amount — these were already being written to
//         the orders table at checkout, but were never read back,
//         so Order Details had no way to show a real breakdown
//         (only the flat total_amount and per-item prices).
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

/// Thrown by markAsShipped when a Lalamove courier already appears to
/// be booked for this order. Prevents a stale/retried tap from
/// dispatching a second real courier.
class AlreadyBookedException implements Exception {
  final String message;
  AlreadyBookedException(this.message);

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
          subtotal,
          shipping,
          discount_amount,
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
        .or('order_type.neq.In-Store,order_type.is.null')
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

    if (status == 'Completed') {
      // Stock was already committed at approval time (Pending -> Confirmed,
      // see PaymentService.approvePayment). Completed is purely a status
      // transition here — do NOT call complete_order_and_commit_stock,
      // it would double-deduct stock that's already been taken.
      await _supabase
          .from('orders')
          .update({'order_status': status})
          .eq('order_id', orderId);

      await _supabase.from('order_progress').insert({
        'order_id':   orderId,
        'status':     status,
        'admin_note': adminNote,
      });
    } else if (status == 'Cancelled') {
    // Atomically releases the reservation AND flips order_status +
    // inserts order_progress.
    await _supabase.rpc('cancel_order_and_release_stock', params: {
      'p_order_id': orderId,
      'p_admin_note': adminNote,
    });
  } else {
    // All other transitions (Confirmed, Preparing, manual Shipped
    // override) — unchanged from before, no stock implications.
    final Map<String, dynamic> updatePayload = {
      'order_status': status,
    };

    if (trackingUrl != null && trackingUrl.trim().isNotEmpty) {
      updatePayload['tracking_url'] = trackingUrl.trim();
      updatePayload['tracking_source'] = 'manual';
    }

    await _supabase
        .from('orders')
        .update(updatePayload)
        .eq('order_id', orderId);

    await _supabase.from('order_progress').insert({
      'order_id':   orderId,
      'status':     status,
      'admin_note': adminNote,
    });
  }

  await _notifyCustomerOrderStatus(orderId: orderId, status: status);

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
Future<LalamoveOrderResult> markAsShipped({
    required Order order,
    String? adminNote,
  }) async {
    if (!order.hasCoordinates) {
      throw OrderMissingCoordinatesException();
    }

    final int orderId = int.parse(order.orderId);

    // Re-check the SERVER's copy of this order (not the possibly
    // stale `order` object passed in) before booking. Closes the gap
    // where a previous attempt booked a real courier but the DB
    // write after it failed/timed out — leaving order_status still
    // 'Preparing' with no lalamove_order_id, which would otherwise
    // let admin tap "Mark Shipped" again and dispatch a 2nd courier.
    final Map<String, dynamic>? currentRow = await _supabase
        .from('orders')
        .select('order_status, lalamove_order_id')
        .eq('order_id', orderId)
        .maybeSingle();

    final String? existingLalamoveId = currentRow?['lalamove_order_id'] as String?;
    final String? currentStatus      = currentRow?['order_status'] as String?;

    if (existingLalamoveId != null && existingLalamoveId.isNotEmpty) {
      throw AlreadyBookedException(
        'A Lalamove courier was already booked for this order '
        '(id: $existingLalamoveId). Refresh before trying again — '
        'do not book a second courier.',
      );
    }
    if (currentStatus == 'Shipped' || currentStatus == 'Delivered' || currentStatus == 'Completed') {
      throw AlreadyBookedException(
        'This order is already marked "$currentStatus". Refresh the '
        'order list — no further booking is needed.',
      );
    }

    // Derive a rough parcel size from actual order contents instead
    // of a hardcoded default (see Fix 6 below).
    final int totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final double estimatedKg = totalQty * 1.2; // rough per-pair estimate — tune this
    final String weightClass = estimatedKg > 20
        ? 'LESS_THAN_20_KG'
        : (estimatedKg > 5 ? 'LESS_THAN_5_KG' : 'LESS_THAN_3_KG');
    // NOTE: verify these weight-class strings against Lalamove's
    // current /v3 enum for your market — they're inferred here, not
    // confirmed from docs.

    // 1. Book the real Lalamove delivery order.
    final LalamoveOrderResult result = await _lalamoveService.createDeliveryOrder(
      orderId: orderId,
      dropoffLat: order.lat!,
      dropoffLng: order.lng!,
      dropoffAddressText: order.address,
      recipientName: order.customerName,
      recipientPhone: order.contact,
      itemQuantity: totalQty > 0 ? totalQty : 1,
      weightClass: weightClass,
    );

    // 2. Save the results + move to Shipped.
    await _supabase.from('orders').update({
      'order_status': 'Shipped',
      'tracking_url': result.trackingUrl,
      'lalamove_order_id': result.lalamoveOrderId,
      'tracking_source': 'lalamove_auto',
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

    await _notifyCustomerOrderStatus(orderId: orderId, status: 'Shipped');

    return result;
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
        .update({
          'tracking_url': trackingUrl.trim(),
          'tracking_source': 'manual',
        })
        .eq('order_id', orderId);
await _activityLog.log(
      action: 'Updated tracking link for order #$orderId',
      affectedModule: AffectedModule.orders,
      targetId: orderId.toString(),
    );
  }

  // ================================================
  // NOTIFY CUSTOMER — ORDER STATUS CHANGED
  // Fires on every status transition (Confirmed, Preparing,
  // Shipped, Delivered/Completed, Cancelled). Non-critical —
  // a notification failure must never block the actual status
  // update, which has already succeeded by the time this runs.
  //
  // RESTORED: this method (and its two call sites above) was
  // accidentally deleted during an unrelated edit that added
  // subtotal/shipping/discount reading to this file.
  // ================================================
  Future<void> _notifyCustomerOrderStatus({
    required int orderId,
    required String status,
  }) async {
    try {
      final row = await _supabase
          .from('orders')
          .select('user_id')
          .eq('order_id', orderId)
          .single();

      final String? customerId = row['user_id'] as String?;
      if (customerId == null) return;

      final String title;
      final String body;
      switch (status) {
        case 'Confirmed':
          title = 'Order confirmed';
          body = 'Order #$orderId has been confirmed and is being prepared.';
          break;
        case 'Preparing':
          title = 'Order is being prepared';
          body = 'Order #$orderId is being packed for shipment.';
          break;
        case 'Shipped':
          title = 'Order shipped';
          body = 'Order #$orderId is on its way to you.';
          break;
        case 'Delivered':
          title = 'Order delivered';
          body = 'Order #$orderId has been delivered. Enjoy!';
          break;
        case 'Completed':
          title = 'Order completed';
          body = 'Order #$orderId is complete. Thanks for shopping with us!';
          break;
        case 'Cancelled':
          title = 'Order cancelled';
          body = 'Order #$orderId has been cancelled.';
          break;
        default:
          title = 'Order update';
          body = 'Order #$orderId status changed to $status.';
      }

      await _supabase.from('notifications').insert({
        'customer_id': customerId,
        'type': 'order',
        'title': title,
        'body': body,
        'order_id': orderId,
        'recipient_role': 'customer',
      });
    } catch (error) {
      print('_notifyCustomerOrderStatus error: $error');
    }
  }
}
