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
import '../../../widgets/common/dialog/app_toast.dart';
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

  /// Told when an order or payment is in progress (true) and when it has
  /// finished (false), so the checkout screen can refuse to leave this step
  /// (Back link, progress bar, system Back) in the middle of a payment.
  final ValueChanged<bool>?    onBusyChanged;

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
    this.onBusyChanged,
  });

  @override
  State<CheckoutStep3Payment> createState() =>
      _CheckoutStep3PaymentState();
}

class _CheckoutStep3PaymentState
    extends State<CheckoutStep3Payment> {
  bool _isProcessing = false;
  bool _placeOrderInFlight = false;

  // The main button says what will actually happen for the chosen method.
  String get _actionLabel {
    switch (widget.selectedMethod) {
      case 'gcash':
        return 'PAY WITH GCASH';
      case 'card':
        return 'ENTER CARD DETAILS';
      default:
        return 'PLACE ORDER';
    }
  }

  Future<void> _handlePlaceOrder() async {
    // Synchronous guard, checked BEFORE the confirm dialog even opens.
    // _isProcessing alone wasn't enough — it only gets set true AFTER
    // the dialog resolves, leaving a real window where rapid taps each
    // independently start their own call and each place a real order.
    if (_placeOrderInFlight) return;
    _placeOrderInFlight = true;
    widget.onBusyChanged?.call(true);

    try {
      await _placeOrderInternal();
    } finally {
      // BOTH flags reset here — _placeOrderInFlight was previously
      // never reset, meaning every attempt after the very first one
      // on this screen instance silently did nothing at all.
      _placeOrderInFlight = false;
      widget.onBusyChanged?.call(false);
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  // One short confirmation for EVERY method, in the same square black-and-white
  // look as the other customer dialogs. Creating the order reserves stock, so a
  // stray tap should not be able to do that. The wording says what happens next
  // and never calls an unpaid order "placed" or "paid".
  Future<bool?> _showPlaceOrderConfirm() {
    final String total = formatPeso(widget.total);
    final String title;
    final String body;
    final String confirmLabel;

    switch (widget.selectedMethod) {
      case 'gcash':
        title = 'PAY WITH GCASH?';
        body = 'We will create your order for $total and take you to a secure '
            'GCash payment page. Your order is not confirmed until the payment '
            'goes through.';
        confirmLabel = 'CONTINUE TO GCASH';
        break;
      case 'card':
        title = 'PAY WITH CARD?';
        body = 'We will create your order for $total, then ask for your card '
            'details. Your order is not confirmed until the payment goes '
            'through.';
        confirmLabel = 'CONTINUE';
        break;
      default:
        title = 'PLACE YOUR ORDER?';
        body = 'Your order of $total will be placed now. You pay in cash when '
            'it arrives, and our team will check your address before '
            'confirming.';
        confirmLabel = 'PLACE ORDER';
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF4C4546),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: Colors.black,
                    alignment: Alignment.center,
                     child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCFC4C5)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrderInternal() async {
    // The in-flight guard in _handlePlaceOrder was set before this runs, so
    // rapid taps cannot open a second dialog or start a second order.
    final bool? confirmed = await _showPlaceOrderConfirm();
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
      if (mounted) {
        AppToast.error(context, e.message, title: 'Item unavailable');
      }
    } on PaymentGatewayException catch (e) {
      if (mounted) {
        AppToast.error(context, e.message, title: 'Payment problem');
      }
    } on InsufficientStockException catch (e) {
      if (mounted) {
        AppToast.error(context, e.message, title: 'Not enough stock');
      }
    } on SessionExpiredException catch (e) {
      if (mounted) {
        AppToast.warning(context, e.message, title: 'Session expired');
      }
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on TooManyAttemptsException catch (e) {
      if (mounted) {
        AppToast.warning(context, e.message, title: 'Too many attempts');
      }
    } on AccountSuspendedException catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          e.message,
          title: 'Account suspended',
          duration: const Duration(seconds: 8),
        );
      }
      await Supabase.instance.client.auth.signOut();
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Something went wrong. Please try again.');
      }
    
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================================================
  // SAFE TOAST
  // Best-effort only — a courtesy notification must never be allowed to
  // throw and abort whatever comes after it (the order already succeeded;
  // a failure here once blocked navigation to Order History).
  // ================================================
  void _showSafeToast(
    AppToastType type,
    String message, {
    String? title,
    Duration? duration,
  }) {
    try {
      final BuildContext? ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      AppToast.show(ctx, type, message, title: title, duration: duration);
    } catch (_) {
      // never let a notification break checkout
    }
  }

    
  Future<void> _handleCod(int orderId) async {
    await PaymentService().setCodPending(orderId: orderId);

    _goToOrderHistory();

    _showSafeToast(
      AppToastType.success,
      'Admin will verify your address and confirm your order.',
      title: 'Order placed',
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

    _showSafeToast(
      AppToastType.info,
      'Your order will appear once payment is confirmed.',
      title: 'Complete your GCash payment',
      duration: const Duration(seconds: 6),
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

      _showSafeToast(
        AppToastType.success,
        'Your order is being reviewed by our team.',
        title: 'Payment successful',
      );
    }
  }

  void _goToOrderHistory() {
    // Deferred one frame so the toast is registered before the page
    // changes. (The toast lives above the navigator, so it survives the
    // navigation.)
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
                      // Directly under the payment options and left-aligned
                      // with them. The last option already leaves its own gap.
                      _BackButton(
                        onTap: widget.onBack,
                        enabled: !(_isProcessing || _placeOrderInFlight),
                      ),
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
                  actionLabel:    _actionLabel,
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
            // Payment options, then Back, then the summary with the main button.
            _BackButton(
              onTap: widget.onBack,
              enabled: !(_isProcessing || _placeOrderInFlight),
            ),
            const SizedBox(height: 8),
            CheckoutOrderSummary(
              items:          widget.items,
              subtotal:       widget.subtotal,
              shipping:       widget.shipping,
              total:          widget.total,
              showPlaceOrder: true,
              isProcessing:   _isProcessing,
              onPlaceOrder:   _handlePlaceOrder,
              actionLabel:    _actionLabel,
              // On a phone the item list starts folded, so the total and the
              // button are visible without scrolling.
              collapsibleItems: true,
            ),
          ],
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  /// False while a payment is in progress: leaving the step then could leave an
  /// order half-created. The link stays in place but greyed out.
  final bool enabled;

  const _BackButton({required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final Color color =
        enabled ? const Color(0xFF656464) : const Color(0xFFCFC4C5);

    // The padding makes the tap area about 44px tall without changing how the
    // link looks.
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Back to review',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                'BACK TO REVIEW',
                style: TextStyle(
                  fontFamily:    'Inter',
                  fontSize:      12,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 2.0,
                  color:         color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}