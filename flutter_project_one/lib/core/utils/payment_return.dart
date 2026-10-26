import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/customer/orders/order_history_screen.dart';
import '../../widgets/common/dialog/app_toast.dart';

// ================================================
// PAYMENT RETURN (website)
//
// After a GCash or card payment on PayMongo's page, the customer's browser is
// sent back to:
//     https://<your site>/order-history?order=123        (they finished)
//     https://<your site>/order-history?cancelled=1      (they backed out)
//
// That is a full page load. The website had nothing that read the address, so
// it just opened the normal start screen and the customer never saw their
// order. (The Android app already handles its own dgeekickz://payment-success
// link in main.dart.)
//
// This opens the EXISTING Order History screen on top of the start screen.
//
// IMPORTANT: coming back to this address proves NOTHING about payment. Anyone
// can type it in. So the message never says "paid". The order's real status
// comes from the server, which only changes after PayMongo's signed
// confirmation (the webhook), and Order History shows that status.
// ================================================

enum PaymentReturnKind { none, returned, cancelled }

class PaymentReturn {
  final PaymentReturnKind kind;
  final String? orderId;

  const PaymentReturn(this.kind, [this.orderId]);

  /// Reads an address. Anything that is not /order-history is "none".
  static PaymentReturn parse(Uri uri) {
    String path = uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path != '/order-history') {
      return const PaymentReturn(PaymentReturnKind.none);
    }

    if (uri.queryParameters['cancelled'] == '1') {
      return const PaymentReturn(PaymentReturnKind.cancelled);
    }

    final String? order = uri.queryParameters['order'];
    final bool looksLikeAnOrderNumber =
        order != null && RegExp(r'^\d{1,12}$').hasMatch(order);

    return PaymentReturn(
      PaymentReturnKind.returned,
      looksLikeAnOrderNumber ? order : null,
    );
  }
}

/// Call once when the website starts (after the first frame).
///
/// Does nothing on the Android app, when the address is not /order-history,
/// or when nobody is signed in (the normal start screen then asks them to log
/// in). Opening the same address again just shows Order History again; it
/// never creates an order or a charge.
void handleWebPaymentReturn(GlobalKey<NavigatorState> navigatorKey) {
  if (!kIsWeb) return;

  final PaymentReturn result = PaymentReturn.parse(Uri.base);
  if (result.kind == PaymentReturnKind.none) return;

  if (Supabase.instance.client.auth.currentUser == null) return;

  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
    // Keep the start screen underneath, so Back goes home. Same as the
    // Android app's payment-success link.
    (route) => route.isFirst,
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    if (result.kind == PaymentReturnKind.cancelled) {
      AppToast.info(
        context,
        'Your payment was not completed, so your order is still waiting for payment.',
        title: 'Payment cancelled',
      );
    } else {
      AppToast.info(
        context,
        'We\'re confirming your payment. Your order status below will update '
        'once it is confirmed.',
        title: 'Checking your payment',
      );
    }
  });
}