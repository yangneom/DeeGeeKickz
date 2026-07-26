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

  Future<double> _getCostPrice(int? sizeId) async {
    if (sizeId == null) return 0;
    try {
      final row = await _supabase
          .from('product_variant_size')
          .select('product_variant(cost_price)')
          .eq('size_id', sizeId)
          .single();
      final variant = row['product_variant'];
      return (variant?['cost_price'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      print('_getCostPrice error: $e');
      return 0;
    }
  }

  /// Creates the order + order_item rows (Awaiting Payment, In-Store),
  /// reserves stock, then asks PayMongo for a GCash checkout session.
  /// Returns the orderId + checkoutUrl so the caller can render a QR.
  Future<CashierCheckoutResult> startOnlinePayment({
    required List<Map<String, dynamic>> cartItems, // same shape _saveSale() builds
    required double subtotal,
    required double discountAmount,
    required double total,
  }) async {

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
      final double costPrice = await _getCostPrice(item['sizeId'] as int?);

      await _supabase.from('order_item').insert({
        'order_id': orderId,
        'product_id': item['productId'],
        'size_id': item['sizeId'],
        'quantity': item['quantity'],
        'unit_price': item['retailPrice'],
        'subtotal': item['subtotal'],
        'cost_price_snapshot': costPrice,
        'product_name_snapshot': item['productName'],
        'brand_snapshot': item['brand'],
        'color_snapshot': item['color'],
        'size_snapshot': item['size'],
      });
    }

    

    // 3. Reserve stock so the cashier can't double-sell while the QR
    //    is on screen. If this fails (someone else took the last
    //    unit between add-to-cart and checkout), the order and
    //    order_item rows already written above must not be left
    //    behind as an orphaned, un-payable "Awaiting Payment" order
    //    — delete them and let the exception propagate so the
    //    cashier sees a clear error.
    try {
      await _paymentService.reserveStock(orderId: orderId);
    } catch (e) {
      await _supabase.from('order_item').delete().eq('order_id', orderId);
      await _supabase.from('orders').delete().eq('order_id', orderId);
      rethrow;
    }

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
  /// paying. Since this order never had a real payment attempt from
  /// the customer's side (no scan, no money moved), there's nothing
  /// worth auditing — fully delete it instead of leaving a permanent
  /// 'Cancelled' record cluttering Order Approval / Sales Management.
  Future<void> cancelPendingOrder(int orderId) async {
    // Release the stock reservation first.
    await _paymentService.releaseStockForOrder(orderId: orderId);

    // Delete child rows before the parent order (FK constraints).
    await _supabase.from('payment').delete().eq('order_id', orderId);
    await _supabase.from('order_item').delete().eq('order_id', orderId);
    await _supabase.from('order_progress').delete().eq('order_id', orderId);
    await _supabase.from('orders').delete().eq('order_id', orderId);
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

