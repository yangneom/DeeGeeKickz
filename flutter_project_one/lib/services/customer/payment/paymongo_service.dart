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

class PaymentGatewayException implements Exception {
  final String message;
  PaymentGatewayException(this.message);

  @override
  String toString() => message;
}

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
        throw PaymentGatewayException(
          'Could not start GCash payment. Please try again in a moment.',
        );
      }

      return PaymongoCheckoutResult(
        checkoutUrl: data['checkoutUrl'] as String,
        sessionId:   data['sessionId']   as String,
      );
    } catch (e) {
      print('PaymongoService.createGcashCheckout error: $e');
      if (e is PaymentGatewayException) rethrow;
      throw PaymentGatewayException(
        'Could not start GCash payment. Please check your connection and try again.',
      );
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
          'paymentMethodAllowed':  ['card'],
          'platform':      kIsWeb ? 'web' : 'mobile',
        },      );

      final data = response.data;

      if (data == null) {
        throw PaymentGatewayException(
          'No response from the payment processor. Please try again.',
        );
      }

      if (data['error'] != null) {
        final err = data['error'];
        final code = (err is Map ? err['code'] ?? '' : '').toString();
        throw PaymentGatewayException(_cardDeclineMessage(code));
      }

      final status = data['status'] as String? ?? '';

      if (status != 'succeeded' && status != 'paid') {
        throw PaymentGatewayException(
          'Payment was not completed. Please try a different card or payment method.',
        );
      }

    } catch (e) {
      print('PaymongoService.payWithCard error: $e');
      if (e is PaymentGatewayException) rethrow;
      throw PaymentGatewayException(
        'Your card could not be charged. Please try again.',
      );
    }
  }

  // ================================================
  // MAP A PAYMONGO DECLINE CODE TO A FRIENDLY MESSAGE
  // ================================================
  String _cardDeclineMessage(String code) {
    switch (code) {
      case 'card_declined':
        return 'Your card was declined. Please try a different card.';
      case 'insufficient_funds':
        return 'Your card has insufficient funds.';
      case 'expired_card':
        return 'Your card has expired. Please use a different card.';
      case 'invalid_cvc':
      case 'incorrect_cvc':
        return 'The card\'s CVC is incorrect. Please check and try again.';
      case 'processing_error':
        return 'There was a problem processing your card. Please try again.';
      default:
        return 'Your card could not be charged. Please try a different card or payment method.';
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