import 'package:supabase_flutter/supabase_flutter.dart';
import '../../customer/payment/payment_service.dart';
import '../../customer/payment/paymongo_service.dart';

// ================================================
// CASHIER ONLINE PAYMENT SERVICE
//
// Walk-in QR payment flow for the cashier module.
// Deliberately reuses PaymentService + PaymongoService
// instead of re-implementing reservation/session logic:
//   - PaymentService.reserveStock      (new method)
//   - PaymentService.createPayment     (existing)
//   - PaymentService.savePaymongoSession (existing)
//   - PaymentService.rejectPayment     (existing — used on cancel)
//   - PaymongoService.createGcashCheckout (existing, same call
//     the customer checkout flow already uses)
//
// The order is only finalized (stock committed, order_status
// = 'Completed') by the paymongo-webhook edge function once
// PayMongo confirms payment — see webhook notes.
// ================================================

class CashierOnlinePaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PaymentService _paymentService = PaymentService();
  final PaymongoService _paymongoService = PaymongoService();

  /// Creates the order + order_item rows (Awaiting Payment, In-Store),
  /// reserves stock, then asks PayMongo for a GCash checkout session.
  /// Returns the orderId + checkoutUrl so the caller can render a QR.
  Future<CashierCheckoutResult> startOnlinePayment({
    required List<Map<String, dynamic>> cartItems, // same shape _saveSale() builds
    required double subtotal,
    required double discountAmount,
    required double total,
  }) async {

      // ── TEMP DEBUG ──
    print('CHECKOUT: user = ${_supabase.auth.currentUser?.id}');
    print('CHECKOUT: session exists = ${_supabase.auth.currentSession != null}');
    print('CHECKOUT: access token expiry = ${_supabase.auth.currentSession?.expiresAt}');
    print('CHECKOUT: role claim = ${_supabase.auth.currentSession?.accessToken.split(".")[1]}');
    // ── END TEMP DEBUG ──
    // 1. Create the order — mirrors CashierSaleService, but
    //    'Awaiting Payment' instead of 'Completed' since nothing's

    //    been paid yet.
   final String cashierId = _supabase.auth.currentUser!.id;

    final orderRes = await _supabase
        .from('orders')
        .insert({
          'user_id': cashierId,
          'address_id': null,
          'subtotal': subtotal,
          'shipping': 0,
          'total_amount': total,
          'payment_method': 'gcash',
          'order_status': 'Awaiting Payment',
          'order_type': 'In-Store',
          'discount_amount': discountAmount,
        })
        .select('order_id')
        .single();

    final int orderId = orderRes['order_id'] as int;

    // 2. order_item rows — same field mapping _saveSale() already uses.
    for (final item in cartItems) {
      await _supabase.from('order_item').insert({
        'order_id': orderId,
        'product_id': item['productId'],
        'size_id': item['sizeId'],
        'quantity': item['quantity'],
        'unit_price': item['retailPrice'],
        'subtotal': item['subtotal'],
        'product_name_snapshot': item['productName'],
        'brand_snapshot': item['brand'],
        'color_snapshot': item['color'],
        'size_snapshot': item['size'],
      });
    }

    // 3. Reserve stock so the cashier can't double-sell while the QR
    //    is on screen.
    await _paymentService.reserveStock(orderId: orderId);

    // 4. Create the Pending payment row FIRST (no session yet) —
    //    matches the same insert -> update pattern PaymentService
    //    already uses elsewhere.
    await _paymentService.createPayment(
      orderId: orderId,
      paymentMethod: 'gcash',
      amountPaid: total,
    );

    // 5. Reuse the exact same GCash checkout call the customer
    //    checkout flow uses — no new edge function needed.
    final PaymongoCheckoutResult checkout =
        await _paymongoService.createCashierCheckout(
      orderId: orderId,
      amount: total,
      customerName: 'Walk-in Customer',
      customerEmail: 'walkin@deegeekickz.com',
    );

    // 6. Attach the session to the payment row. This is safe even if
    //    create-checkout already wrote it server-side — it just
    //    overwrites with the same values.
    await _paymentService.savePaymongoSession(
      orderId: orderId,
      sessionId: checkout.sessionId,
      paymongoCheckoutUrl: checkout.checkoutUrl,
    );

    return CashierCheckoutResult(
      orderId: orderId,
      checkoutUrl: checkout.checkoutUrl,
    );
  }

  /// Cashier hit "Cancel Payment", or the QR timed out with nobody
  /// paying. Releases the stock reservation and cancels the order —
  /// reuses PaymentService.rejectPayment rather than duplicating that
  /// logic.
  Future<void> cancelPendingOrder(int orderId) async {
    await _paymentService.rejectPayment(
      orderId: orderId,
      reason: 'Cashier cancelled — QR payment not completed',
    );
  }
}

class CashierCheckoutResult {
  final int orderId;
  final String checkoutUrl;

  const CashierCheckoutResult({
    required this.orderId,
    required this.checkoutUrl,
  });
}