import 'package:flutter/material.dart';

import '../../../models/product_detail_model.dart';
import '../../../screens/customer/messages/customer_chat_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/customer/customer_cart_provider.dart';
import '../../../models/customer_cart_item.dart';



/// Product info panel: name, series, price, rating, size picker,
/// quantity selector, and the three CTA buttons.
///
/// Accepts optional [discountPercent] and [originalPrice] from promo
/// navigation — when present, shows a sale banner, strikethrough
/// original price, and the discounted price in bold.
class ProductInfoSection extends ConsumerStatefulWidget {
  final ProductDetailModel product;
  final int? discountPercent;
  final double? originalPrice;

  const ProductInfoSection({
    super.key,
    required this.product,
    this.discountPercent,
    this.originalPrice,
  });

  @override
  ConsumerState<ProductInfoSection> createState() => _ProductInfoSectionState();
}

class _ProductInfoSectionState extends ConsumerState<ProductInfoSection> {
  String? _selectedSize;
  int _quantity = 1;
  bool _isFavorited = false;

  bool get _isOnSale =>
      widget.discountPercent != null && widget.discountPercent! > 0;

  void _decrementQty() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  void _incrementQty() => setState(() => _quantity++);

void _onAddToBag() {
  if (_selectedSize == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PLEASE SELECT A SIZE'),
      ),
    );
    return;
  }

  final product = widget.product;

  final cartItem = CustomerCartItem(
    productId: product.id,
    productName: product.name,
    brand: product.brand,
    color: 'Default',
    size: _selectedSize!,
    retailPrice: product.price,
    imageUrl: product.imageUrls.first,
    quantity: _quantity,
  );

  ref
      .read(customerCartProvider.notifier)
      .addItem(cartItem);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${product.name} added to bag',
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Sale banner (promo only) ────────────────────────────
        if (_isOnSale) ...[
          Container(
            width: double.infinity,
            color: const Color(0xFFBA1A1A),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.local_offer,
                    color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  'PROMO — ${widget.discountPercent}% OFF  ·  LIMITED TIME',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Name + favourite ────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.series.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Color(0xFF5F5E5E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () =>
                  setState(() => _isFavorited = !_isFavorited),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color(0xFFCFC4C5)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  _isFavorited
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 22,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Price row ───────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Current (discounted or regular) price
            Text(
              product.formattedPrice,
              style: const TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            // Original price strikethrough (promo only)
            if (_isOnSale && widget.originalPrice != null) ...[
              const SizedBox(width: 12),
              Text(
                '\$${widget.originalPrice!.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF7E7576),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Color(0xFF7E7576),
                ),
              ),
              const SizedBox(width: 10),
              // Savings chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                color: const Color(0xFFBA1A1A),
                child: Text(
                  'SAVE \$${(widget.originalPrice! - product.price).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],

            const SizedBox(width: 16),

            // Rating
            const Icon(Icons.star_rounded,
                color: Colors.black, size: 18),
            const SizedBox(width: 4),
            Text(
              product.rating.toStringAsFixed(1),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${_formatCount(product.reviewCount)} Reviews)',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF4C4546),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Size selection ──────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SELECT SIZE (US)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: Colors.black,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Size Guide',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF4C4546),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: product.sizes.length,
          itemBuilder: (context, index) {
            final size = product.sizes[index];
            final isSelected = _selectedSize == size.label;
            final isUnavailable = !size.available;

            return GestureDetector(
              onTap: isUnavailable
                  ? null
                  : () => setState(
                      () => _selectedSize = size.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : const Color(0xFFCFC4C5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  size.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isSelected
                        ? Colors.white
                        : isUnavailable
                            ? const Color(0xFFCFC4C5)
                            : Colors.black,
                    decoration: isUnavailable
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Quantity ────────────────────────────────────────────
        const Text(
          'QUANTITY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCFC4C5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
                  icon: Icons.remove,
                  onTap: _decrementQty,
                  enabled: _quantity > 1),
              Container(
                width: 56,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(
                        color: Color(0xFFCFC4C5), width: 1),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
              ),
              _QtyButton(
                  icon: Icons.add,
                  onTap: _incrementQty,
                  enabled: true),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── CTAs ────────────────────────────────────────────────
        _CtaButton(
            label: 'Add to Bag', filled: true, onTap: _onAddToBag),
        const SizedBox(height: 12),
        _CtaButton(label: 'Buy Now', filled: false, onTap: () {}),
        const SizedBox(height: 8),

        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CustomerChatScreen(),
              ),
            );
          },
          icon: const Icon(Icons.chat_bubble_outline,
              size: 18, color: Color(0xFF656464)),
          label: const Text(
            'CHAT SUPPORT',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: Color(0xFF656464),
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.black : const Color(0xFFCFC4C5),
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _CtaButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
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
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color:
                widget.filled ? Colors.black : Colors.transparent,
            border: Border.all(
              color: Colors.black,
              width: widget.filled ? 0 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color:
                  widget.filled ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
  
}