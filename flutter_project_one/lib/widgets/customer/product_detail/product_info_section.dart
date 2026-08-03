import 'package:flutter/material.dart';
import '../../../core/utils/auth_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import '../../../models/product.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/discount_model.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';
import '../../../screens/customer/messages/customer_chat_screen.dart';
import '../../../screens/customer/checkout/checkout_screen.dart'; 
import '../../../providers/customer/chat_provider.dart';
import '../../../providers/auth/auth_provider.dart';
/// Product info panel backed by the real [Product] model.
/// Color picker → variant images update gallery via callback (future).
/// Size picker → shows only sizes with available stock.
///
/// If this product has an active discount, the sale price is shown
/// (strikethrough original + red sale price) and — importantly — the
/// DISCOUNTED price is what gets stored on the CustomerCartItem when
/// "Add to Bag" is tapped. Since Cart/Checkout just sum item.subtotal,
/// this is the only place the discount needs to be applied for it to
/// flow through correctly everywhere downstream.
class ProductInfoSection extends ConsumerStatefulWidget {
  final Product product;
 
  const ProductInfoSection({super.key, required this.product});
 
  @override
  ConsumerState<ProductInfoSection> createState() =>
      _ProductInfoSectionState();
}
 
class _ProductInfoSectionState
    extends ConsumerState<ProductInfoSection> {
  late ProductVariant _selectedVariant;
  String? _selectedSize;
  int _quantity = 1;
  bool _isFavorited = false;

  // Active discount for this product, if any.
  ActiveDiscounts? _activeDiscounts;
 
  @override
  void initState() {
    super.initState();
    // Default to first variant
    _selectedVariant = widget.product.variants.first;
    _loadDiscount();
  }

  Future<void> _loadDiscount() async {
  final ActiveDiscounts discounts = await DiscountService().fetchActiveDiscounts();
  if (!mounted) return;
  setState(() => _activeDiscounts = discounts);
}

Discount? get _discount {
  final int? pid = int.tryParse(widget.product.productId);
  if (pid == null || _activeDiscounts == null) return null;
  return _activeDiscounts!.resolve(
    productId: pid,
    variantId: _selectedVariant.variantId,
  );
}

  // Applies the active discount (if any) to a base price.
  double _applyDiscount(double basePrice) {
    if (_discount == null) return basePrice;
    double result;
    if (_discount!.discountType == 'Percentage') {
      result = basePrice - (basePrice * (_discount!.discountValue / 100));
    } else {
      result = basePrice - _discount!.discountValue;
    }
    return result < 0 ? 0 : result;
  }
 
  void _selectVariant(ProductVariant v) {
    setState(() {
      _selectedVariant = v;
      _selectedSize = null; // reset size on color change
      _quantity = 1;
    });
  }
 
  void _decrementQty() {
    if (_quantity > 1) setState(() => _quantity--);
  }
 
  void _incrementQty() {
    final max = _availableQtyForSize;
    if (_quantity < max) setState(() => _quantity++);
  }
 
  /// Available qty for the currently selected size
  int get _availableQtyForSize {
    if (_selectedSize == null) return 0;
    final entry = _selectedVariant.sizes
        .cast<SizeEntry?>()
        .firstWhere((s) => s!.size == _selectedSize,
            orElse: () => null);
    return entry?.availableQty ?? 0;
  }
 
  /// Finds the SizeEntry matching the currently selected size string,
  /// so we can pull its real sizeId (FK to product_variant_size).
  SizeEntry? get _selectedSizeEntry {
    if (_selectedSize == null) return null;
    return _selectedVariant.sizes
        .cast<SizeEntry?>()
        .firstWhere((s) => s!.size == _selectedSize, orElse: () => null);
  }
 
  void _onBuyNow() {
    if (_selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a size')),
      );
      return;
    }

    if (_availableQtyForSize == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This size is out of stock')),
      );
      return;
    }

    final int? sizeId = _selectedSizeEntry?.sizeId;
    final double unitPrice = _applyDiscount(_selectedVariant.retailPrice);

    final cartItem = CustomerCartItem(
      productId: int.tryParse(widget.product.productId) ?? 0,  // ← was a raw String
      productName: widget.product.productName,
      brand: widget.product.brand,
      color: _selectedVariant.color,
      size: _selectedSize!,
      sizeId: sizeId,
      retailPrice: unitPrice,
      originalPrice: _selectedVariant.retailPrice,
      imageUrl: _selectedVariant.primaryImageUrl ?? '',
      quantity: _quantity,
    );
 
    ref.read(customerCartProvider.notifier).addItem(cartItem);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  void _onAddToBag() {
    if (_selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a size')),
      );
      return;
    }
 
    if (_availableQtyForSize == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This size is out of stock')),
      );
      return;
    }
 
    // Real FK to product_variant_size — required for stock reservation
    // at checkout. If this is null, the size lookup failed and the
    // cart item will not be reservable/orderable correctly.
    final int? sizeId = _selectedSizeEntry?.sizeId;

    // Apply the active discount now, so the cart stores the price the
    // customer actually saw and agreed to — Cart/Checkout don't need
    // to know about discounts at all, they just sum this value.
    final double unitPrice = _applyDiscount(_selectedVariant.retailPrice);
 
    final cartItem = CustomerCartItem(
      productId: int.tryParse(widget.product.productId) ?? 0,  // ← was a raw String
      productName: widget.product.productName,
      brand: widget.product.brand,
      color: _selectedVariant.color,
      size: _selectedSize!,
      sizeId: sizeId,
      retailPrice: unitPrice,
      imageUrl: _selectedVariant.primaryImageUrl ?? '',
      quantity: _quantity,
    );
 
    ref.read(customerCartProvider.notifier).addItem(cartItem);
 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${widget.product.productName} added to bag'),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final price = _selectedVariant.retailPrice;
    final double displayPrice = _applyDiscount(price);
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Brand · Category ──────────────────────────────────
        Text(
          '${product.brand} · ${product.category}'.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: Color(0xFF5F5E5E),
          ),
        ),
        const SizedBox(height: 6),
 
        // ── Name + favourite ──────────────────────────────────
        
        // ── Name ────────────────────────────────────────────
        Text(
          product.productName.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.1,
            color: Colors.black,
          ),
        ),
 
        const SizedBox(height: 16),
 
        // ── Price ─────────────────────────────────────────────
        _discount != null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${displayPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFBA1A1A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '₱${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Color(0xFF9CA3AF),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                '₱${price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
 
        const SizedBox(height: 24),
 
        // ── Color picker ──────────────────────────────────────
        if (product.variants.length > 1) ...[
          Text(
            'COLOR: ${_selectedVariant.color.toUpperCase()}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: product.variants.map((v) {
              final isSelected = v.variantId ==
                  _selectedVariant.variantId;
              return GestureDetector(
                onTap: () => _selectVariant(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
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
                    v.color,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
 
        // ── Size picker ───────────────────────────────────────
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
          itemCount: _selectedVariant.sizes.length,
          itemBuilder: (context, index) {
            final sizeEntry =
                _selectedVariant.sizes[index];
            final isSelected =
                _selectedSize == sizeEntry.size;
            final isUnavailable =
                sizeEntry.availableQty == 0;
 
            return GestureDetector(
              onTap: isUnavailable
                  ? null
                  : () => setState(
                      () => _selectedSize = sizeEntry.size),
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 150),
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
                  sizeEntry.size,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
 
        // ── Quantity ──────────────────────────────────────────
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
            border:
                Border.all(color: const Color(0xFFCFC4C5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: _decrementQty,
                enabled: _quantity > 1,
              ),
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(
                    vertical: 10),
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(
                        color: Color(0xFFCFC4C5),
                        width: 1),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: _incrementQty,
                enabled: _selectedSize != null &&
                    _quantity < _availableQtyForSize,
              ),
            ],
          ),
        ),
 
        // Stock hint
        if (_selectedSize != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$_availableQtyForSize available',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF4C4546),
              ),
            ),
          ),
 
        const SizedBox(height: 32),
 
        // ── CTAs ──────────────────────────────────────────────
        _CtaButton(
            label: 'Add to Bag',
            filled: true,
            onTap: _onAddToBag),
        const SizedBox(height: 12),
        _CtaButton(
            label: 'Buy Now', filled: false, onTap: _onBuyNow),
        const SizedBox(height: 8),
 
        // Chat Support only makes sense for logged-in users — Guests
        // have no account to attach a conversation to, so hide it
        // entirely instead of showing-then-redirecting to Login.
        Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authStateProvider);
            final isLoggedIn = authState.value?.session?.user != null;

            if (!isLoggedIn) return const SizedBox.shrink();

            return TextButton.icon(
              onPressed: () {
                ref.read(pendingChatProductProvider.notifier).set(
                  PendingChatProduct(
                    productId: product.productId,
                    productName: product.productName,
                  ),
                );
                requireAuth(context, const CustomerChatScreen());
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
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(double.infinity, 48),
              ),
            );
          },
        ),
      ],
    );
  }
}
 
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
 
  const _QtyButton(
      {required this.icon,
      required this.onTap,
      required this.enabled});
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Icon(icon,
            size: 20,
            color: enabled
                ? Colors.black
                : const Color(0xFFCFC4C5)),
      ),
    );
  }
}
 
class _CtaButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
 
  const _CtaButton(
      {required this.label,
      required this.filled,
      required this.onTap});
 
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
            color: widget.filled
                ? Colors.black
                : Colors.transparent,
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
              color: widget.filled
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}