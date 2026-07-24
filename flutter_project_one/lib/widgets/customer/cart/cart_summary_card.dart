import 'package:flutter/material.dart';
import '../../../screens/customer/checkout/checkout_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../screens/auth/login_screen.dart';

/// Order summary sidebar card — matches HTML mockup.
/// Shows subtotal, a "calculated at checkout" shipping note, and
/// Checkout CTA.
///
/// NOTE: We used to show a fake flat ₱10 "Estimated Shipping" number
/// here. It was removed because it had no connection to the real
/// Lalamove price shown later at checkout (which is based on the
/// customer's actual address) — showing an unrelated number here
/// made the total jump unexpectedly once the real fee appeared,
/// which felt misleading to the customer. Now this screen only
/// shows the subtotal, which is the only number we can actually
/// know for sure at this point (no address has been picked yet).
class CartSummaryCard extends StatelessWidget {
  final double subtotal;

  const CartSummaryCard({
    super.key,
    required this.subtotal,
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
            value: '₱${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),

          // ── Shipping note (no number shown here) ─────
          // We only know the real shipping fee once the customer
          // picks a delivery address in checkout, so we don't guess
          // at a number on this screen anymore.
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF656464),
                ),
              ),
              Text(
                'Calculated at checkout',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFCFC4C5), thickness: 1, height: 1),
          const SizedBox(height: 12),

          // ── Total ────────────────────────────────────
          // Total here = subtotal only. Shipping isn't added in
          // until checkout, once a real fee is known — so this
          // number will still be accurate when the customer sees
          // it, it's just not the FINAL total yet.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SUBTOTAL',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
              Text(
                '₱${subtotal.toStringAsFixed(2)}',
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