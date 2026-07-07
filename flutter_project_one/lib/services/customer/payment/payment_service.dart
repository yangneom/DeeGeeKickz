import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// PAYMENT SERVICE
//
// payment_status vocabulary:
//   'Pending'   — no money confirmed yet (COD before delivery,
//                 or gcash/card before gateway confirms)
//   'Verified'  — gateway (PayMongo) confirmed the charge for an
//                 Online gcash/card order, but admin has not yet
//                 approved it. NOT a finalized sale yet.
//   'Paid'      — finalized sale. For gcash/card this is set only
//                 by approvePayment() (admin action). For COD this
//                 is set only when order_status reaches 'Completed'
//                 (see OrderManagementService.updateOrderStatus).
//                 For In-Store walk-in QR sales, the webhook sets
//                 this immediately since there's no approval step.
//   'Rejected'  — admin rejected the order while Pending.
//   'Refunded' / 'Refund Failed' — set when a Verified/Paid order
//                 is cancelled and a refund is attempted.
//
// STOCK:
//   approvePayment  -> commits stock (deducts real
//                      stock_quantity, releases reservation)
//   rejectPayment   -> releases reservation only
//   cancelOrder     -> releases reservation only
// ================================================

class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);

  @override
  String toString() => message;
}

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // CREATE PAYMENT ROW
  // ================================================
  Future<void> createPayment({
    required int    orderId,
    required String paymentMethod,
    required double amountPaid,
    String?         paymongoSessionId,
    String?         paymongoCheckoutUrl,
  }) async {
    try {
      await _supabase.from('payment').insert({
        'order_id':                orderId,
        'payment_method':          paymentMethod,
        'amount_paid':             amountPaid,
        'payment_date':            DateTime.now().toIso8601String(),
        'payment_status':          'Pending',
        if (paymongoSessionId   != null)
          'reference_number':      paymongoSessionId,
        if (paymongoCheckoutUrl != null)
          'gateway_response':      paymongoCheckoutUrl,
      });
    } catch (e) {
      print('PaymentService.createPayment error: $e');
      rethrow;
    }
  }

  // Add this public method to PaymentService
  Future<void> reserveStock({required int orderId}) async {
    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('size_id, quantity')
        .eq('order_id', orderId);

    for (final dynamic item in items) {
      final int? sizeId = item['size_id'] as int?;
      final int quantity = (item['quantity'] as num).toInt();
      if (sizeId == null) continue;

      final row = await _supabase
          .from('product_variant_size')
          .select('reserved_quantity')
          .eq('size_id', sizeId)
          .single();

      final int current = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
      await _supabase
          .from('product_variant_size')
          .update({'reserved_quantity': current + quantity})
          .eq('size_id', sizeId);
    }
  }

  // ================================================
  // SAVE RECEIPT URL
  // ================================================
  Future<void> saveReceiptUrl({
    required int    orderId,
    required String receiptUrl,
  }) async {
    try {
      await _supabase
          .from('payment')
          .update({'receipt_url': receiptUrl})
          .eq('order_id', orderId);
    } catch (e) {
      print('PaymentService.saveReceiptUrl error: $e');
      rethrow;
    }
  }

  // ================================================
  // SAVE PAYMONGO SESSION
  // ================================================
  Future<void> savePaymongoSession({
    required int    orderId,
    required String sessionId,
    required String paymongoCheckoutUrl,
  }) async {
    try {
      await _supabase.from('payment').update({
        'reference_number': sessionId,
        'gateway_response': paymongoCheckoutUrl,
      }).eq('order_id', orderId);
    } catch (e) {
      print('PaymentService.savePaymongoSession error: $e');
      rethrow;
    }
  }

  // ================================================
  // APPROVE PAYMENT (admin)
  //
  // Sets order_status = Confirmed.
  //
  // gcash / card: money already passed through the gateway before
  //   admin ever saw this order (payment_status was set to
  //   'Verified' by the webhook/payment-intent function on gateway
  //   confirmation). Approval finalizes it — payment_status becomes
  //   'Paid' here.
  //
  // cod: no money has moved yet — cash is only collected by the
  //   courier on delivery. Approval here just means admin has
  //   reviewed and accepted the order for fulfillment; payment_status
  //   stays untouched (remains 'Pending') and only becomes 'Paid'
  //   once the order is marked 'Completed'
  //   (see OrderManagementService.updateOrderStatus).
  // ================================================
  Future<void> approvePayment({required int orderId}) async {
    try {
      // Commit stock FIRST — if this throws (insufficient
      // stock), nothing below runs, so payment/order status
      // stay untouched and the order remains at Pending.
      await _commitStock(orderId: orderId);

      final String adminId = _supabase.auth.currentUser!.id;

      final Map<String, dynamic>? paymentRow = await _supabase
          .from('payment')
          .select('payment_method')
          .eq('order_id', orderId)
          .maybeSingle();

      final String method = (paymentRow?['payment_method'] ?? '').toString();
      final bool isCod = method.toLowerCase() == 'cod';

      final Map<String, dynamic> paymentUpdate = {
        'verified_by': adminId,
        'verified_at': DateTime.now().toIso8601String(),
      };
      if (!isCod) {
        paymentUpdate['payment_status'] = 'Paid';
      }

      await _supabase
          .from('payment')
          .update(paymentUpdate)
          .eq('order_id', orderId);

      await _supabase
          .from('orders')
          .update({'order_status': 'Confirmed'})
          .eq('order_id', orderId);

      await _supabase.from('order_progress').insert({
        'order_id':   orderId,
        'status':     'Confirmed',
        'admin_note': 'Payment verified and approved.',
      });
    } on InsufficientStockException {
      // Let this propagate as-is — the UI shows its message
      // directly and the order is left untouched at Pending.
      rethrow;
    } catch (e) {
      print('PaymentService.approvePayment error: $e');
      rethrow;
    }
  }

  // ================================================
  // REJECT PAYMENT (admin)
  //
  // Sets payment_status = 'Rejected'
  // Sets order_status   = 'Cancelled'
  // Logs to order_progress
  // SMS sent by caller (order_details_dialog)
  //
  // NOTE: No automatic refund here — admin manually
  // refunds on dashboard.paymongo.com if the customer
  // had already paid. The customer cancel flow (below)
  // handles automatic refunds instead.
  // ================================================
  Future<void> rejectPayment({
    required int    orderId,
    required String reason,
  }) async {
    try {
      final String adminId = _supabase.auth.currentUser!.id;

      // 1. Release the stock reservation — this order
      //    never got approved, so nothing was deducted,
      //    only the reservation needs to be given back.
      await _releaseStock(orderId: orderId);

      // 2. Mark payment as Rejected
      await _supabase.from('payment').update({
        'payment_status': 'Rejected',
        'verified_by':    adminId,
        'verified_at':    DateTime.now().toIso8601String(),
      }).eq('order_id', orderId);

      // 3. Cancel the order
      await _supabase.from('orders').update({
        'order_status': 'Cancelled',
      }).eq('order_id', orderId);

      // 4. Log to order_progress
      await _supabase.from('order_progress').insert({
        'order_id':   orderId,
        'status':     'Cancelled',
        'admin_note': 'Payment rejected by admin: $reason',
      });

    } catch (e) {
      print('PaymentService.rejectPayment error: $e');
      rethrow;
    }
  }

  /// Public wrapper around _releaseStock, for callers outside this
  /// service (e.g. CashierOnlinePaymentService) that need to release
  /// a reservation without going through rejectPayment's full flow.
  Future<void> releaseStockForOrder({required int orderId}) async {
    await _releaseStock(orderId: orderId);
  }

  // ================================================
  // CANCEL ORDER (customer)
  //
  // A customer can only cancel while the order is still 'Pending'
  // (i.e. before admin has approved it). For gcash/card, the
  // gateway may have already confirmed the charge by this point
  // (payment_status = 'Verified'), so a refund must be issued and
  // the payment row must be updated to reflect that — it should
  // never be left claiming a status that implies money is still
  // held/finalized when it isn't.
  // ================================================
  Future<void> cancelOrder({
    required int    orderId,
    required String reason,
    required String cancelledBy,
  }) async {
    try {
      // Release the stock reservation regardless of who
      // cancelled — the order was never approved, so only
      // the reservation needs to be given back.
      await _releaseStock(orderId: orderId);

      await _supabase.from('orders').update({
        'order_status': 'Cancelled',
      }).eq('order_id', orderId);

      await _supabase.from('order_progress').insert({
        'order_id':   orderId,
        'status':     'Cancelled',
        'admin_note': 'Cancelled by $cancelledBy: $reason',
      });

      // Check whether the gateway had already confirmed this
      // payment (or, belt-and-suspenders, whether it was somehow
      // already marked Paid) before the cancellation happened.
      final Map<String, dynamic>? paymentRow = await _supabase
          .from('payment')
          .select('payment_status')
          .eq('order_id', orderId)
          .maybeSingle();

      final String currentPaymentStatus =
          (paymentRow?['payment_status'] ?? '').toString();
      final bool wasPaid = currentPaymentStatus == 'Verified' ||
          currentPaymentStatus == 'Paid';

      if (wasPaid) {
        // Attempt refund via gateway first.
        bool refundSucceeded = false;
        try {
          await _supabase.functions.invoke(
            'refund-payment',
            body: {
              'orderId': orderId,
              'reason':  reason,
            },
          );
          refundSucceeded = true;
        } catch (refundErr) {
          print('PaymentService.cancelOrder refund error: $refundErr');
        }

        // Reflect the outcome on the payment row so payment_status
        // never stays stuck at 'Verified'/'Paid' for a cancelled order.
        await _supabase.from('payment').update({
          'payment_status': refundSucceeded ? 'Refunded' : 'Refund Failed',
        }).eq('order_id', orderId);
      }
    } catch (e) {
      print('PaymentService.cancelOrder error: $e');
      rethrow;
    }
  }

  // ================================================
  // FETCH PAYMENT FOR ORDER
  // ================================================
  Future<Map<String, dynamic>?> getPaymentForOrder(int orderId) async {
    try {
      final List<dynamic> result = await _supabase
          .from('payment')
          .select()
          .eq('order_id', orderId)
          .limit(1);

      if (result.isEmpty) return null;
      return result.first as Map<String, dynamic>;
    } catch (e) {
      print('PaymentService.getPaymentForOrder error: $e');
      return null;
    }
  }

  // ================================================
  // COMMIT STOCK (admin approval)
  // Deducts real stock_quantity and releases the
  // matching reservation, for every item in the order.
  // Throws InsufficientStockException if any item no
  // longer has enough stock — approval should be
  // blocked and the order left at Pending in that case.
  // ================================================
  Future<void> _commitStock({required int orderId}) async {
    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('size_id, quantity, product_name_snapshot')
        .eq('order_id', orderId);

    // Validate every item BEFORE committing any of them,
    // so we never partially commit an order.
    for (final dynamic item in items) {
      final int? sizeId = item['size_id'] as int?;
      final int quantity = (item['quantity'] as num).toInt();
      if (sizeId == null) continue; // legacy rows with no size_id — skip

      final row = await _supabase
          .from('product_variant_size')
          .select('stock_quantity')
          .eq('size_id', sizeId)
          .single();

      final int stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;

      if (stock < quantity) {
        final String name =
            item['product_name_snapshot'] ?? 'An item';
        throw InsufficientStockException(
          '$name no longer has enough stock '
          '(needs $quantity, only $stock available). '
          'Approval was cancelled — no changes were made.',
        );
      }
    }

    // All items validated — now actually commit each one.
    for (final dynamic item in items) {
      final int? sizeId = item['size_id'] as int?;
      final int quantity = (item['quantity'] as num).toInt();
      if (sizeId == null) continue;

      final row = await _supabase
          .from('product_variant_size')
          .select('stock_quantity, reserved_quantity')
          .eq('size_id', sizeId)
          .single();

      final int stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      final int reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;

     await _supabase.from('product_variant_size').update({
        'reserved_quantity':
            (reserved - quantity) < 0 ? 0 : reserved - quantity,
      }).eq('size_id', sizeId);
    }
  }

  // ================================================
  // RELEASE STOCK (rejection / cancellation)
  // Only releases the reservation — stock_quantity was
  // never deducted for an order that wasn't approved,
  // so there's nothing to give back there.
  // ================================================
  Future<void> _releaseStock({required int orderId}) async {
    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('size_id, quantity')
        .eq('order_id', orderId);

    for (final dynamic item in items) {
      final int? sizeId = item['size_id'] as int?;
      final int quantity = (item['quantity'] as num).toInt();
      if (sizeId == null) continue;

      final row = await _supabase
          .from('product_variant_size')
          .select('reserved_quantity')
          .eq('size_id', sizeId)
          .single();

      final int reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;

      await _supabase.from('product_variant_size').update({
        'reserved_quantity':
            (reserved - quantity) < 0 ? 0 : reserved - quantity,
      }).eq('size_id', sizeId);
    }
  }

  // ================================================
  // SET COD PENDING
  // COD orders skip payment entirely.
  // Moves order from 'Awaiting Payment' to 'Pending'
  // so it appears in admin approval immediately.
  // ================================================
  Future<void> setCodPending({required int orderId}) async {
    try {
      await _supabase
          .from('orders')
          .update({'order_status': 'Pending'})
          .eq('order_id', orderId);

      await _supabase.from('order_progress').insert({
        'order_id':   orderId,
        'status':     'Pending',
        'admin_note': 'Cash on Delivery order — awaiting admin approval.',
      });
    } catch (e) {
      print('PaymentService.setCodPending error: $e');
      rethrow;
    }
  }
}