import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';

/// Step 2 — Review order + shipping address before payment.
///
/// WHAT CHANGED
///   - The address card is compact: 16px padding (was 24), smaller text, and a
///     header row that keeps "SHIPPING TO" and "EDIT" on one aligned line.
///   - Lines with nothing in them are not printed. The name and phone used to be
///     passed in as empty text, which left blank lines in the card.
///   - If there is no address at all, a centered "no address" message with a
///     button back to Shipping is shown (and Continue is not offered).
///   - The Continue button now sits directly under the order total, inside the
///     summary, instead of floating in the middle of the page above it. There is
///     still exactly ONE primary button.
///   - Gaps between sections are 20px on phones (were 48px).
///
/// The inputs are unchanged, so the checkout screen needs no other change.
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

  bool get _hasAddress =>
      street.trim().isNotEmpty || city.trim().isNotEmpty;

  Widget _summary() {
    return CheckoutOrderSummary(
      items: items,
      subtotal: subtotal,
      shipping: shipping,
      total: total,
      showPlaceOrder: true,
      // No address means there is nothing to continue with: the button takes
      // the customer back to Shipping instead.
      actionLabel: _hasAddress ? 'CONTINUE TO PAYMENT' : 'CHOOSE AN ADDRESS',
      onPlaceOrder: _hasAddress ? onContinue : onEditShipping,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isDesktop = constraints.maxWidth >= 1024;

      final Widget details = _ReviewDetails(
        fullName: [firstName, lastName]
            .where((String s) => s.trim().isNotEmpty)
            .join(' '),
        street: street,
        cityLine: [city, postal]
            .where((String s) => s.trim().isNotEmpty)
            .join(', '),
        country: country,
        phone: phone,
        hasAddress: _hasAddress,
        onEditShipping: onEditShipping,
      );

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: review details (7/12)
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(right: 40),
                child: details,
              ),
            ),
            // Right: summary with the Continue button under the total (5/12)
            Expanded(
              flex: 5,
              child: _summary(),
            ),
          ],
        );
      }

      // Mobile: address, then the summary with the button directly under the
      // total.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          details,
          const SizedBox(height: 20),
          _summary(),
        ],
      );
    });
  }
}

class _ReviewDetails extends StatelessWidget {
  final String fullName;
  final String street;
  final String cityLine;
  final String country;
  final String phone;
  final bool hasAddress;
  final VoidCallback onEditShipping;

  const _ReviewDetails({
    required this.fullName,
    required this.street,
    required this.cityLine,
    required this.country,
    required this.phone,
    required this.hasAddress,
    required this.onEditShipping,
  });

  static const TextStyle _lineStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.4,
    color: Color(0xFF4C4546),
  );

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Your Order',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: compact ? 28 : 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        SizedBox(height: compact ? 16 : 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F4),
            border: Border.all(color: const Color(0xFFCFC4C5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label and Edit on one aligned line.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'SHIPPING TO',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: Color(0xFF656464),
                      ),
                    ),
                  ),
                  // The padding makes the tap area comfortable without
                  // changing how the word looks.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditShipping,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      child: Text(
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
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (hasAddress) ...[
                if (fullName.isNotEmpty)
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                if (street.trim().isNotEmpty) Text(street, style: _lineStyle),
                if (cityLine.isNotEmpty) Text(cityLine, style: _lineStyle),
                if (country.trim().isNotEmpty) Text(country, style: _lineStyle),
                if (phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(phone, style: _lineStyle),
                ],
              ] else
                // No address: a centered message and a way back to Shipping.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_outlined,
                            size: 32, color: Color(0xFF9CA3AF)),
                        const SizedBox(height: 8),
                        const Text(
                          'No shipping address yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Choose where we should deliver your order.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF656464),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onEditShipping,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFCFC4C5)),
                            ),
                            child: const Text(
                              'ADD AN ADDRESS',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}