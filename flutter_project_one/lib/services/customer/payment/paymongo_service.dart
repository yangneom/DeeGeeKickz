import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/customer/checkout/card_payment_dialog.dart';
import 'package:flutter/foundation.dart';

// ================================================
// PAYMONGO SERVICE
//
// GCash  → calls create-checkout edge function
//           (returns a redirect URL)
// Card   → calls create-payment-intent edge function
//           (in-house, no redirect)
// COD    → no PayMongo call at all
// ================================================

class PaymongoService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // GCASH — Checkout Session (redirect)
  // ================================================
  Future<PaymongoCheckoutResult> createGcashCheckout({
    required int    orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-checkout',
        body: {
          'orderId':       orderId,
          'amount':        amount,
          'customerName':  customerName,
          'customerEmail': customerEmail,
          'paymentMethod': 'gcash',
          'platform':      kIsWeb ? 'web' : 'mobile',
        },
      );

      final data = response.data;
      if (data == null || data['checkoutUrl'] == null) {
        throw Exception('Invalid response: $data');
      }

      return PaymongoCheckoutResult(
        checkoutUrl: data['checkoutUrl'] as String,
        sessionId:   data['sessionId']   as String,
      );
    } catch (e) {
      print('PaymongoService.createGcashCheckout error: $e');
      rethrow;
    }
  }

  // ================================================
  // COMBINED GCASH + CARD — for cashier QR payments
  // Same edge function as createGcashCheckout, but
  // passes a paymentMethod value that isn't 'gcash' or
  // 'card' so create-checkout's method-type branch
  // returns both options on the PayMongo checkout page.
  // ================================================
  Future<PaymongoCheckoutResult> createCashierCheckout({
    required int    orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-checkout',
        body: {
          'orderId':       orderId,
          'amount':        amount,
          'customerName':  customerName,
          'customerEmail': customerEmail,
          'paymentMethod': 'gcash_and_card',
          'platform':      kIsWeb ? 'web' : 'mobile',
        },
      );

      final data = response.data;
      if (data == null || data['checkoutUrl'] == null) {
        throw Exception('Invalid response: $data');
      }

      return PaymongoCheckoutResult(
        checkoutUrl: data['checkoutUrl'] as String,
        sessionId:   data['sessionId']   as String,
      );
    } catch (e) {
      print('PaymongoService.createCashierCheckout error: $e');
      rethrow;
    }
  }

  // ================================================
  // CARD — Payment Intent (in-house, no redirect)
  // ================================================
  Future<void> payWithCard({
    required int         orderId,
    required double      amount,
    required String      customerName,
    required String      customerEmail,
    required CardDetails card,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'orderId':       orderId,
          'amount':        amount,
          'customerName':  customerName,
          'customerEmail': customerEmail,
          'cardNumber':    card.cardNumber,
          'expMonth':      card.expMonth,
          'expYear':       card.expYear,
          'cvc':           card.cvc,
          'cardHolder':    card.cardHolderName,
          'paymentMethodAllowed':  ['card'],  // ← ADD THIS
        },
      );

      final data = response.data;

      if (data == null) {
        throw Exception('No response from payment intent');
      }

      if (data['error'] != null) {
        final err = data['error'];
        final code = err is Map ? err['code'] ?? '' : '';
        throw Exception(code.isNotEmpty ? code : 'payment_failed');
      }

      final status = data['status'] as String? ?? '';

      if (status != 'succeeded' && status != 'paid') {
        throw Exception('Payment not completed. Status: $status');
      }

    } catch (e) {
      print('PaymongoService.payWithCard error: $e');
      rethrow;
    }
  }
}

// ================================================
// RESULT MODEL — for GCash only
// ================================================
class PaymongoCheckoutResult {
  final String checkoutUrl;
  final String sessionId;

  const PaymongoCheckoutResult({
    required this.checkoutUrl,
    required this.sessionId,
  });
}