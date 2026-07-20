import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/customer_cart_item.dart';
import '../../../services/customer/payment/paymongo_service.dart';
import '../../../services/customer/payment/payment_service.dart';
import '../../../widgets/customer/checkout/checkout_payment_selector.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';
import '../../../widgets/customer/checkout/card_payment_dialog.dart';
import '../../../widgets/common/dialog/confirm_dialog.dart';
import '../orders/order_history_screen.dart';
import '../../../main.dart';

class CheckoutStep3Payment extends StatefulWidget {
  final String                 selectedMethod;
  final ValueChanged<String>   onMethodChanged;
  final List<CustomerCartItem> items;
  final double                 subtotal;
  final double                 shipping;
  final double                 tax;
  final double                 total;
  final Future<int> Function() onPlaceOrder;
  final String                 customerName;
  final String                 customerEmail;
  final VoidCallback           onBack;

  const CheckoutStep3Payment({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.onPlaceOrder,
    required this.customerName,
    required this.customerEmail,
    required this.onBack,
  });

  @override
  State<CheckoutStep3Payment> createState() =>
      _CheckoutStep3PaymentState();
}

class _CheckoutStep3PaymentState
    extends State<CheckoutStep3Payment> {
  bool _isProcessing = false;

  // ================================================
  // HANDLE PLACE ORDER — routes by payment method
  // ================================================
  Future<void> _handlePlaceOrder() async {
    final bool? confirmed = await showConfirmDialog(
      context:      context,
      title:        'Place this order?',
      message:      widget.selectedMethod == 'cod'
          ? 'Your order will be placed and the admin will '
            'verify your address. Pay cash on delivery.'
          : widget.selectedMethod == 'gcash'
          ? 'You will be redirected to GCash to complete '
            'payment. Your order will be placed immediately.'
          : 'You will enter your card details to complete '
            'payment. Your order will be placed immediately.',
      confirmLabel: 'Place Order',
      confirmColor: const Color(0xFF111827),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Step 1 — create order in DB
      final int orderId = await widget.onPlaceOrder();

      // Step 2 — route by payment method
      if (widget.selectedMethod == 'cod') {
        await _handleCod(orderId);
      } else if (widget.selectedMethod == 'gcash') {
        await _handleGcash(orderId);
      } else if (widget.selectedMethod == 'card') {
        await _handleCard(orderId);
      }

    } catch (e) {
      print('CheckoutStep3._handlePlaceOrder error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Something went wrong. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================================================
  // COD — no payment, set directly to Pending
  // ================================================
  Future<void> _handleCod(int orderId) async {
    // COD orders skip payment entirely.
    // order_status is already 'Awaiting Payment' from createOrder.
    // We update it to 'Pending' directly so it appears in
    // admin approval without needing a webhook.
    await PaymentService().setCodPending(orderId: orderId);

    print('COD: order $orderId set to pending, navigating to Order History');

    ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
      const SnackBar(
        content: Text(
          'Order placed! Admin will verify your address '
          'and confirm your order.',
        ),
        duration: Duration(seconds: 4),
      ),
    );

    _goToOrderHistory();
  }

  // ================================================
  // GCASH — redirect to GCash
  // ================================================
  Future<void> _handleGcash(int orderId) async {
    final result = await PaymongoService().createGcashCheckout(
      orderId:       orderId,
      amount:        widget.total,
      customerName:  widget.customerName,
      customerEmail: widget.customerEmail,
    );

    final Uri url = Uri.parse(result.checkoutUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open GCash');
    }

    print('GCash: checkout opened for order $orderId, navigating to Order History');

    ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
      const SnackBar(
        content: Text(
          'Complete your GCash payment. Your order will '
          'appear once payment is confirmed.',
        ),
        duration: Duration(seconds: 5),
      ),
    );

    // Deep links only work on mobile (see main.dart's `if (!kIsWeb)`
    // guard) — on web there's no automatic return path, so navigate
    // away from checkout immediately rather than leaving the user on
    // a now-empty-cart checkout screen after the tab opens GCash.
    _goToOrderHistory();
  }

  // ================================================
  // CARD — in-house card form
  // ================================================
  Future<void> _handleCard(int orderId) async {
    // Release processing state while dialog is open
    if (mounted) setState(() => _isProcessing = false);

    final bool? paid = await showCardPaymentDialog(
      context:      context,
      total:        widget.total,
      customerName: widget.customerName,
      onPay: (CardDetails card) async {
        await PaymongoService().payWithCard(
          orderId:       orderId,
          amount:        widget.total,
          customerName:  widget.customerName,
          customerEmail: widget.customerEmail,
          card:          card,
        );
      },
    );

    print('Card: dialog closed with paid=$paid for order $orderId');

    if (paid == true) {
      ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment successful! Your order is being '
            'reviewed by our team.',
          ),
          backgroundColor: Color(0xFF16A34A),
          duration:        Duration(seconds: 4),
        ),
      );

      _goToOrderHistory();
    }
  }

  // ── Uses the GLOBAL navigator key, not local context — CheckoutScreen
  // unmounts this widget the instant the cart clears (its build() has
  // an `if (items.isEmpty)` guard), so a local Navigator.of(context)
  // call here would silently no-op. The global key sidesteps that.
  void _goToOrderHistory() {
    print('_goToOrderHistory called, navigatorState = ${appNavigatorKey.currentState}');
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
      (route) => route.isFirst,
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckoutPaymentSelector(
                        selectedMethod: widget.selectedMethod,
                        onChanged:      widget.onMethodChanged,
                      ),
                      const SizedBox(height: 32),
                      _BackButton(onTap: widget.onBack),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: CheckoutOrderSummary(
                  items:          widget.items,
                  subtotal:       widget.subtotal,
                  shipping:       widget.shipping,
                  tax:            widget.tax,
                  total:          widget.total,
                  showPlaceOrder: true,
                  isProcessing:   _isProcessing,
                  onPlaceOrder:   _handlePlaceOrder,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckoutPaymentSelector(
              selectedMethod: widget.selectedMethod,
              onChanged:      widget.onMethodChanged,
            ),
            const SizedBox(height: 48),
            CheckoutOrderSummary(
              items:          widget.items,
              subtotal:       widget.subtotal,
              shipping:       widget.shipping,
              tax:            widget.tax,
              total:          widget.total,
              showPlaceOrder: true,
              isProcessing:   _isProcessing,
              onPlaceOrder:   _handlePlaceOrder,
            ),
            const SizedBox(height: 24),
            _BackButton(onTap: widget.onBack),
          ],
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 16, color: Color(0xFF656464)),
          SizedBox(width: 8),
          Text(
            'BACK TO REVIEW',
            style: TextStyle(
              fontFamily:    'Inter',
              fontSize:      12,
              fontWeight:    FontWeight.w600,
              letterSpacing: 2.0,
              color:         Color(0xFF656464),
            ),
          ),
        ],
      ),
    );
  }
}