import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';

/// Right-side order summary panel on the checkout screen.
/// Shows product thumbnails, line totals, and Place Order CTA.
///
/// UPDATE: Tax row removed — this business only charges for the
/// item price + Lalamove shipping fee, no separate tax line.
/// UPDATE: currency symbol changed from $ to ₱ (Philippine peso)
/// throughout, since this is a PH-only nationwide store.
/// UPDATE: added shippingUnavailable — previously a shipping fee of
/// exactly 0 was always displayed as "FREE", but Step 1 now also
/// passes 0 while a quote is blocked/failed (see
/// CheckoutStep1Shipping._fetchShippingQuote). That made a blocked,
/// unpriceable address look like a legitimate free-shipping offer.
/// When true, this shows "—" for both Shipping and Total instead of
/// guessing. Defaults to false so Step 2/3 (only reachable once a
/// real quote succeeded) don't need to pass anything new.
class CheckoutOrderSummary extends StatelessWidget {
  final List<CustomerCartItem> items;
  final double subtotal;
  final double shipping;
  final double total;
  final VoidCallback onPlaceOrder;
  final bool showPlaceOrder;
  final bool isProcessing;
  final bool shippingUnavailable;

  const CheckoutOrderSummary({
    super.key,
    required this.items,
    required this.subtotal,
    required this.shipping,
  required this.total,
    required this.onPlaceOrder,
    this.showPlaceOrder = true,
    this.isProcessing = false,
    this.shippingUnavailable = false,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),

          // ── Product list ─────────────────────────────
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    // Thumbnail
                    Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFE2E2E2),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Color(0xFF9E9E9E), size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${item.size} | Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4C4546),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(color: Color(0xFFCFC4C5), thickness: 1, height: 32),

          // ── Totals ───────────────────────────────────
          // NOTE: Tax row removed on purpose — only item price +
          // Lalamove shipping fee are charged.
          _Row(label: 'Subtotal', value: '₱${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _Row(
            label: 'Shipping',
            value: shippingUnavailable
                ? '—'
                : shipping == 0.0
                    ? 'FREE'
                    : '₱${shipping.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.black, thickness: 1, height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                shippingUnavailable ? '—' : '₱${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (showPlaceOrder) ...[
            _PlaceOrderButton(
              onTap: onPlaceOrder,
              isProcessing: isProcessing,
            ),
            const SizedBox(height: 16),
          ],

          // Secure badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock, size: 14, color: Color(0xFF656464)),
              SizedBox(width: 6),
              Text(
                'Secure Encrypted Checkout',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF656464),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4C4546))),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: Colors.black)),
      ],
    );
  }
}

class _PlaceOrderButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isProcessing;
  const _PlaceOrderButton({required this.onTap, required this.isProcessing});

  @override
  State<_PlaceOrderButton> createState() => _PlaceOrderButtonState();
}

class _PlaceOrderButtonState extends State<_PlaceOrderButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isProcessing ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isProcessing
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      onTapCancel: widget.isProcessing
          ? null
          : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: widget.isProcessing ? const Color(0xFF656464) : Colors.black,
          alignment: Alignment.center,
          child: widget.isProcessing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'PLACE ORDER',
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