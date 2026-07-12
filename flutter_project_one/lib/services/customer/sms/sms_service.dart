import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// SMS SERVICE
//
// Sends SMS via the send-order-sms Supabase Edge Function
// which calls the IPROG SMS gateway (sms_messages endpoint).
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
  // NORMALIZE PHILIPPINE PHONE NUMBER
  //
  // iProg expects the format: 639XXXXXXXXX
  // (country code, no '+', no leading '0')
  //
  // Handles common formats customers might enter:
  //   09XXXXXXXXX      -> 639XXXXXXXXX
  //   +639XXXXXXXXX    -> 639XXXXXXXXX
  //   639XXXXXXXXX     -> 639XXXXXXXXX (unchanged)
  //   9XXXXXXXXX       -> 639XXXXXXXXX (10 digits, no prefix at all)
  //
  // Strips spaces, dashes, and parentheses first so formats like
  // "0917-123-4567" or "(0917) 123 4567" are handled too.
  // ================================================
  String _normalizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^\d+]'), '');

    // Strip a leading '+' — we only want digits from here on
    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    }

    if (digits.startsWith('0')) {
      // 09XXXXXXXXX -> drop leading 0, prefix with 63
      return '63${digits.substring(1)}';
    }

    if (digits.startsWith('63')) {
      // Already in the right form
      return digits;
    }

    if (digits.length == 10 && digits.startsWith('9')) {
      // Bare 9XXXXXXXXX, no country code or leading 0 at all
      return '63$digits';
    }

    // Fallback: return as-is (already stripped of non-digits) —
    // better to attempt a send with an unexpected format than to
    // silently drop the message entirely.
    return digits;
  }

  // ================================================
  // INTERNAL — calls edge function
  // ================================================
  Future<void> _send({
    required String phone,
    required String message,
  }) async {
    final String normalizedPhone = _normalizePhone(phone);

    try {
      await _supabase.functions.invoke(
        'send-order-sms',
        body: {
          'phone_number': normalizedPhone,
          'message':      message,
        },
      );
    } catch (e) {
      print('SmsService._send error: $e');
      // Do not rethrow — SMS failure should never block the main flow
    }
  }
}