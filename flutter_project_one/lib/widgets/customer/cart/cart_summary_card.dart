import 'package:flutter/material.dart';
import '../../../screens/customer/checkout/checkout_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../screens/auth/login_screen.dart';

/// Order summary sidebar card — matches HTML mockup.
/// Shows subtotal, shipping, tax, total, and Checkout CTA.
class CartSummaryCard extends StatelessWidget {
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;

  const CartSummaryCard({
    super.key,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.black, thickness: 1, height: 1),
          const SizedBox(height: 16),

          // ── Line items ──────────────────────────────
          _SummaryRow(
            label: 'Subtotal',
            value: '\$${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Estimated Shipping',
            value: shipping == 0.0 ? 'FREE' : '\$${shipping.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Tax',
            value: '\$${tax.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFCFC4C5), thickness: 1, height: 1),
          const SizedBox(height: 12),

          // ── Total ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Checkout Button ──────────────────────────
          SizedBox(
            width: double.infinity,
            child: _CheckoutButton(
              onTap: () {
                final user =
                    Supabase.instance.client.auth.currentUser;

                if (user == null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CheckoutScreen(),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF656464),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CheckoutButton({required this.onTap});

  @override
  State<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<_CheckoutButton> {
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Colors.black,
          alignment: Alignment.center,
          child: const Text(
            'CHECKOUT',
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