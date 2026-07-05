import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// SMS SERVICE
//
// Sends SMS via the send-sms Supabase Edge Function
// which calls the Semaphore PH gateway.
//
// Usage:
//   await SmsService().sendOrderRejected(
//     phone: '+639XXXXXXXXX',
//     orderId: '123',
//     reason: 'Invalid address',
//   );
// ================================================

class SmsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // SEND — ORDER REJECTED (admin rejects)
  // ================================================
  Future<void> sendOrderRejected({
    required String phone,
    required String orderId,
    required String reason,
  }) async {
    final String message =
        'DeeGee Kickz: Your order #$orderId has been rejected. '
        'Reason: $reason. '
        'Please contact us if you have questions.';

    await _send(phone: phone, message: message);
  }

  // ================================================
  // SEND — ORDER CANCELLED (customer cancels)
  // ================================================
  Future<void> sendOrderCancelled({
    required String phone,
    required String orderId,
    required String reason,
  }) async {
    final String message =
        'DeeGee Kickz: Your order #$orderId has been cancelled. '
        'Reason: $reason. '
        'Thank you for shopping with us.';

    await _send(phone: phone, message: message);
  }

  // ================================================
  // INTERNAL — calls edge function
  // ================================================
  Future<void> _send({
    required String phone,
    required String message,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-sms',
        body: {
          'to':      phone,
          'message': message,
        },
      );
    } catch (e) {
      print('SmsService._send error: $e');
      // Do not rethrow — SMS failure should never block the main flow
    }
  }
}