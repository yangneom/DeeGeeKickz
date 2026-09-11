import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/customer_cart_item.dart';
import '../../../providers/customer/order_service.dart';
import '../../../services/customer/payment/paymongo_service.dart';
import '../../../services/customer/payment/payment_service.dart';
import '../../../widgets/customer/checkout/checkout_payment_selector.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';
import '../../../widgets/customer/checkout/card_payment_dialog.dart';
import '../../../widgets/common/dialog/confirm_dialog.dart';
import '../orders/order_history_screen.dart';
import '../../auth/login_screen.dart';
import '../../../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _placeOrderInFlight = false;

  Future<void> _handlePlaceOrder() async {
    // Synchronous guard, checked BEFORE the confirm dialog even opens.
    // _isProcessing alone wasn't enough — it only gets set true AFTER
    // the dialog resolves, leaving a real window where rapid taps each
    // independently start their own call and each place a real order.
    if (_placeOrderInFlight) return;
    _placeOrderInFlight = true;

    try {
      await _placeOrderInternal();
    } finally {
      // BOTH flags reset here — _placeOrderInFlight was previously
      // never reset, meaning every attempt after the very first one
      // on this screen instance silently did nothing at all.
      _placeOrderInFlight = false;
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _placeOrderInternal() async {
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
      final int orderId = await widget.onPlaceOrder();

      if (widget.selectedMethod == 'cod') {
        await _handleCod(orderId);
      } else if (widget.selectedMethod == 'gcash') {
        await _handleGcash(orderId);
      } else if (widget.selectedMethod == 'card') {
        await _handleCard(orderId);
      }

    } on ArchivedProductException catch (e) {
      print('CheckoutStep3._handlePlaceOrder archived-product error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } on PaymentGatewayException catch (e) {
      print('CheckoutStep3._handlePlaceOrder payment-gateway error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } on InsufficientStockException catch (e) {
      print('CheckoutStep3._handlePlaceOrder insufficient-stock error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } on SessionExpiredException catch (e) {
      print('CheckoutStep3._handlePlaceOrder session-expired error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
            appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
        } on AccountSuspendedException catch (e) {
      print('CheckoutStep3._handlePlaceOrder account-suspended error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      await Supabase.instance.client.auth.signOut();
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
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
  // SAFE SNACKBAR
  // Best-effort only — a courtesy toast must never be allowed to
  // throw and abort whatever comes after it (confirmed in testing:
  // the order succeeded, but a crash here repeatedly prevented
  // navigation to Order History right after, on every single order).
  // ================================================
  void _showSafeSnackBar(String message, {Color? backgroundColor, Duration? duration}) {
    try {
      final BuildContext? ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('_showSafeSnackBar error (non-critical): $e');
    }
  }

  Future<void> _handleCod(int orderId) async {
    await PaymentService().setCodPending(orderId: orderId);

    _goToOrderHistory();

    _showSafeSnackBar(
      'Order placed! Admin will verify your address and confirm your order.',
    );
  }

  Future<void> _handleGcash(int orderId) async {
    final result = await PaymongoService().createGcashCheckout(
      orderId:       orderId,
      amount:        widget.total,
      customerName:  widget.customerName,
      customerEmail: widget.customerEmail,
    );

    final Uri url = Uri.parse(result.checkoutUrl);
    if (!await launchUrl(
      url,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    )) {
      throw PaymentGatewayException(
        'Could not open GCash. Please try again.',
      );
    }

    _goToOrderHistory();

    _showSafeSnackBar(
      'Complete your GCash payment. Your order will appear once payment is confirmed.',
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _handleCard(int orderId) async {
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

    if (paid == true) {
      _goToOrderHistory();

      _showSafeSnackBar(
        'Payment successful! Your order is being reviewed by our team.',
        backgroundColor: const Color(0xFF16A34A),
      );
    }
  }

  void _goToOrderHistory() {
    // Deferred one frame — navigating away immediately in the same
    // synchronous call as showSnackBar() tears down the Scaffold
    // mid-animation, before the SnackBar has a chance to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
        (route) => route.isFirst,
      );
    });
  }

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