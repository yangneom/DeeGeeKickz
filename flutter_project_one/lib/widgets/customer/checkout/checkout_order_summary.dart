import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';

/// Philippine peso formatting used across checkout: ₱1,234.50
///
/// The old code printed amounts with toStringAsFixed(2) only, so ₱5,500 showed
/// as "₱5500.00" with no thousands separator. This is the one place that
/// formats money in checkout now, so every step shows it the same way.
String formatPeso(double amount) {
  final bool negative = amount < 0;
  final String fixed = amount.abs().toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String whole = parts[0];

  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }

  return '${negative ? '-' : ''}₱${buffer.toString()}.${parts[1]}';
}

/// Order summary panel on the checkout screen.
/// Shows product thumbnails, line totals, the totals block, and (optionally)
/// the main action button, so the button sits right under the total.
///
/// Notes kept from before:
///  - No Tax row: this business only charges item price + Lalamove shipping.
///  - [shippingUnavailable] shows "—" for Shipping and Total while a shipping
///    quote is loading or has failed, instead of a misleading "FREE".
///
/// New (all optional, so every existing caller still compiles unchanged):
///  - [actionLabel]: the text on the main button (default "PLACE ORDER"). The
///    Review step uses "CONTINUE TO PAYMENT"; the Payment step names the
///    chosen method.
///  - [collapsibleItems]: shows the item list folded under an "N items"
///    header (opened with a tap), so on a phone the total and the button are
///    visible without scrolling.
class CheckoutOrderSummary extends StatelessWidget {
  final List<CustomerCartItem> items;
  final double subtotal;
  final double shipping;
  final double total;
  final VoidCallback onPlaceOrder;
  final bool showPlaceOrder;
  final bool isProcessing;
  final bool shippingUnavailable;
  final String actionLabel;
  final bool collapsibleItems;

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
    this.actionLabel = 'PLACE ORDER',
    this.collapsibleItems = false,
  });

  /// Sums each item's own discountSubtotal — correctly handles a cart
  /// with multiple products at different discount rates, since each
  /// item already carries its own originalPrice vs retailPrice.
  double get _totalDiscount =>
      items.fold<double>(0, (sum, item) => sum + item.discountSubtotal);

  Widget _itemRow(CustomerCartItem item, bool compact) {
    final double thumb = compact ? 64 : 80;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 16 : 24),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: thumb,
            height: thumb,
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
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                  formatPeso(item.subtotal),
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
    );
  }

  Widget _itemsSection(BuildContext context, bool compact) {
    final List<Widget> rows =
        items.map((CustomerCartItem item) => _itemRow(item, compact)).toList();

    if (!collapsibleItems) {
      return Column(children: rows);
    }

    // Folded by default. The Theme only removes the default divider lines and
    // tint so the tile matches the rest of the card.
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: const Color(0xFFF3F3F4),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: Colors.black,
        collapsedIconColor: Colors.black,
        textColor: Colors.black,
        collapsedTextColor: Colors.black,
        title: Text(
          '${items.length} ${items.length == 1 ? 'item' : 'items'} in your order',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        children: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.of(context).size.width < 600;
    final double headingSize = compact ? 24 : 32;

    return Container(
      padding: EdgeInsets.all(compact ? 20 : 32),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          Text(
            'ORDER SUMMARY',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: headingSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
          ),
          SizedBox(height: compact ? 16 : 24),

          // ── Product list ─────────────────────────────
          _itemsSection(context, compact),

          Divider(
            color: const Color(0xFFCFC4C5),
            thickness: 1,
            height: compact ? 24 : 32,
          ),

          // ── Totals ───────────────────────────────────
          // NOTE: Tax row removed on purpose — only item price +
          // Lalamove shipping fee are charged.
          _Row(label: 'Subtotal', value: formatPeso(subtotal)),
          if (_totalDiscount > 0) ...[
            const SizedBox(height: 8),
            _Row(
              label: 'You saved',
              value: '-${formatPeso(_totalDiscount)}',
              valueColor: const Color(0xFF16A34A),
            ),
          ],
          const SizedBox(height: 8),
          _Row(
            label: 'Shipping',
            value: shippingUnavailable
                ? '—'
                : shipping == 0.0
                    ? 'FREE'
                    : formatPeso(shipping),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.black, thickness: 1, height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: headingSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              // Shrinks a very large amount instead of overflowing.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    shippingUnavailable ? '—' : formatPeso(total),
                    style: TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: headingSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: compact ? 20 : 24),

          if (showPlaceOrder) ...[
            _PlaceOrderButton(
              label: actionLabel,
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
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

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
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: valueColor ?? Colors.black)),
      ],
    );
  }
}

class _PlaceOrderButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isProcessing;
  const _PlaceOrderButton({
    required this.label,
    required this.onTap,
    required this.isProcessing,
  });

  @override
  State<_PlaceOrderButton> createState() => _PlaceOrderButtonState();
}

class _PlaceOrderButtonState extends State<_PlaceOrderButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !widget.isProcessing,
      label: widget.isProcessing ? 'Processing' : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown:
            widget.isProcessing ? null : (_) => setState(() => _pressed = true),
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
            color:
                widget.isProcessing ? const Color(0xFF656464) : Colors.black,
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
                : Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.0,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}