import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';

/// Step 2 — Review order + shipping address before payment.
class CheckoutStep2Review extends StatelessWidget {
  final String firstName, lastName, street, city, postal, phone, country;
  final List<CustomerCartItem> items;
  final double subtotal, shipping, tax, total;
  final VoidCallback onContinue;
  final VoidCallback onEditShipping;

  const CheckoutStep2Review({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.street,
    required this.city,
    required this.postal,
    required this.phone,
    required this.country,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.onContinue,
    required this.onEditShipping,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1024;

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: review details (7/12)
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(right: 40),
                child: _ReviewDetails(
                  firstName: firstName,
                  lastName: lastName,
                  street: street,
                  city: city,
                  postal: postal,
                  phone: phone,
                  country: country,
                  onEditShipping: onEditShipping,
                  onContinue: onContinue,
                ),
              ),
            ),
            // Right: summary (5/12)
            Expanded(
              flex: 5,
              child: CheckoutOrderSummary(
                items: items,
                subtotal: subtotal,
                shipping: shipping,
                total: total,
                showPlaceOrder: false,
                onPlaceOrder: () {},
              ),
            ),
          ],
        );
      }

      // Mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewDetails(
            firstName: firstName,
            lastName: lastName,
            street: street,
            city: city,
            postal: postal,
            phone: phone,
            country: country,
            onEditShipping: onEditShipping,
            onContinue: onContinue,
          ),
          const SizedBox(height: 48),
          CheckoutOrderSummary(
            items: items,
            subtotal: subtotal,
            shipping: shipping,
            total: total,
            showPlaceOrder: false,
            onPlaceOrder: () {},
          ),
        ],
      );
    });
  }
}

class _ReviewDetails extends StatelessWidget {
  final String firstName, lastName, street, city, postal, phone, country;
  final VoidCallback onEditShipping;
  final VoidCallback onContinue;

  const _ReviewDetails({
    required this.firstName,
    required this.lastName,
    required this.street,
    required this.city,
    required this.postal,
    required this.phone,
    required this.country,
    required this.onEditShipping,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Your Order',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 32),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F4),
            border: Border.all(color: const Color(0xFFCFC4C5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SHIPPING TO',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: Color(0xFF656464),
                    ),
                  ),
                  GestureDetector(
                    onTap: onEditShipping,
                    child: const Text(
                      'EDIT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$firstName $lastName',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                street,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF4C4546),
                ),
              ),
              Text(
                '$city, $postal',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF4C4546),
                ),
              ),
              Text(
                country,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF4C4546),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF4C4546),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        _ContinueToPaymentButton(onTap: onContinue),
      ],
    );
  }
}

class _ContinueToPaymentButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ContinueToPaymentButton({required this.onTap});

  @override
  State<_ContinueToPaymentButton> createState() =>
      _ContinueToPaymentButtonState();
}

class _ContinueToPaymentButtonState
    extends State<_ContinueToPaymentButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Colors.black,
          alignment: Alignment.center,
          child: const Text(
            'CONTINUE TO PAYMENT',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}