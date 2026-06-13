import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';
import '../../../widgets/customer/checkout/checkout_payment_selector.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';

/// Step 3 — Payment method selection + Place Order.
class CheckoutStep3Payment extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onMethodChanged;
  final List<CustomerCartItem> items;
  final double subtotal, shipping, tax, total;
  final VoidCallback onPlaceOrder;
  final VoidCallback onBack;

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
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1024;

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: payment selector (7/12)
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(right: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckoutPaymentSelector(
                      selectedMethod: selectedMethod,
                      onChanged: onMethodChanged,
                    ),
                    const SizedBox(height: 32),
                    _BackButton(onTap: onBack),
                  ],
                ),
              ),
            ),
            // Right: summary with Place Order (5/12)
            Expanded(
              flex: 5,
              child: CheckoutOrderSummary(
                items: items,
                subtotal: subtotal,
                shipping: shipping,
                tax: tax,
                total: total,
                showPlaceOrder: true,
                onPlaceOrder: onPlaceOrder,
              ),
            ),
          ],
        );
      }

      // Mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckoutPaymentSelector(
            selectedMethod: selectedMethod,
            onChanged: onMethodChanged,
          ),
          const SizedBox(height: 48),
          CheckoutOrderSummary(
            items: items,
            subtotal: subtotal,
            shipping: shipping,
            tax: tax,
            total: total,
            showPlaceOrder: true,
            onPlaceOrder: onPlaceOrder,
          ),
          const SizedBox(height: 24),
          _BackButton(onTap: onBack),
        ],
      );
    });
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.arrow_back, size: 16, color: Color(0xFF656464)),
          SizedBox(width: 8),
          Text(
            'BACK TO REVIEW',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: Color(0xFF656464),
            ),
          ),
        ],
      ),
    );
  }
}