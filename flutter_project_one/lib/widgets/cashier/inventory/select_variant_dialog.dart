import 'package:flutter/material.dart';
import '../../../models/product.dart';

// ================================================
// SELECT VARIANT DIALOG
//
// Shows when cashier taps a product card
//
// Lets cashier pick:
//   - Color
//   - Size
//   - Quantity
//
// BLOCKS reserved variants — cashier cannot add
// items that are locked by online orders
// ================================================

void showSelectVariantDialog({
  required BuildContext context,
  required Product product,
  required Function(String color, String size, int quantity, double price) onAddToCart,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return SelectVariantDialog(
        product: product,
        onAddToCart: onAddToCart,
      );
    },
  );
}

class SelectVariantDialog extends StatefulWidget {
  final Product product;
  final Function(String color, String size, int quantity, double price) onAddToCart;

  const SelectVariantDialog({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<SelectVariantDialog> createState() => _SelectVariantDialogState();
}

class _SelectVariantDialogState extends State<SelectVariantDialog> {

  // currently selected color and size
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;

  // ================================================
  // GET UNIQUE COLORS from variants
  // ================================================
  List<String> get _uniqueColors {
    List<String> colors = [];
    for (ProductVariant v in widget.product.variants) {
      if (colors.contains(v.color) == false) {
        colors.add(v.color);
      }
    }
    return colors;
  }

  // ================================================
  // GET SIZES for the selected color
  // ================================================
  List<String> get _sizesForSelectedColor {
    if (_selectedColor == null) return [];
    return widget.product.variants
        .where((ProductVariant v) => v.color == _selectedColor)
        .map((ProductVariant v) => v.size)
        .toList();
  }

  // ================================================
  // GET SELECTED VARIANT
  // ================================================
  ProductVariant? get _selectedVariant {
    if (_selectedColor == null || _selectedSize == null) return null;
    try {
      return widget.product.variants.firstWhere(
        (ProductVariant v) =>
            v.color == _selectedColor && v.size == _selectedSize,
      );
    } catch (_) {
      return null;
    }
  }

  // ================================================
  // GET VARIANT BY COLOR AND SIZE
  // ================================================
  ProductVariant? _getVariant(String color, String size) {
    try {
      return widget.product.variants.firstWhere(
        (ProductVariant v) => v.color == color && v.size == size,
      );
    } catch (_) {
      return null;
    }
  }

  // ================================================
  // IS SIZE AVAILABLE
  // uses availableQty — not stockQty
  // reserved items are treated as unavailable
  // ================================================
  bool _isSizeAvailable(String size) {
    ProductVariant? variant = _getVariant(_selectedColor ?? '', size);
    if (variant == null) return false;
    return variant.availableQty > 0;
  }

  // ================================================
  // IS SIZE RESERVED (fully locked, no available qty)
  // ================================================
  bool _isSizeReserved(String size) {
    ProductVariant? variant = _getVariant(_selectedColor ?? '', size);
    if (variant == null) return false;
    return variant.isFullyReserved;
  }

  // ================================================
  // SHOW RESERVED ERROR POPUP
  // shown when cashier taps a fully reserved variant
  // ================================================
  void _showReservedError() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ---- TITLE ----
              const Text(
                'Item Reserved',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 10),

              // ---- MESSAGE ----
              const Text(
                'This item is fully reserved for an online order and cannot be sold in-store right now.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 10),

              // ---- HINT BOX ----
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE047)),
                ),
                child: const Text(
                  'It will become available again once the online order is approved or declined by the admin.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---- BUTTON ----
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK, Got It',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    final ProductVariant? variant = _selectedVariant;
    final double price = variant?.retailPrice ?? widget.product.averagePrice;

    // use availableQty as the max — not stockQty!
    // cashier cannot sell reserved stock
    final int maxQty = variant?.availableQty ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── TITLE ──
            const Text(
              'Select Variant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose the variant you want to add to the transaction.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── IMAGE PREVIEW ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Item Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── STOCK INFO BOX ──
                    // shows stock / reserved / available
                    // only when a variant is selected
                    if (variant != null)
                      Container(
                        width: 140,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // stock qty
                            _buildStockRow(
                              'Stock',
                              '${variant.stockQty}',
                              const Color(0xFF374151),
                            ),

                            const SizedBox(height: 4),

                            // reserved qty — red if > 0
                            _buildStockRow(
                              'Reserved',
                              '${variant.reservedQty}',
                              variant.reservedQty > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF374151),
                            ),

                            const Divider(
                              height: 12,
                              color: Color(0xFFE5E7EB),
                            ),

                            // available qty — green if > 0, red if 0
                            _buildStockRow(
                              'Available',
                              '${variant.availableQty}',
                              variant.availableQty > 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 20),

                // ── VARIANT SELECTORS ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // price
                      Text(
                        '₱${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── COLOR SELECTOR ──
                      const Text(
                        'Color',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _uniqueColors.map((String color) {
                          final bool isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                                // reset size when color changes
                                _selectedSize = null;
                                _quantity = 1;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFD1D5DB),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                color,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // ── SIZE SELECTOR ──
                      const Text(
                        'Sizes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _selectedColor == null
                          ? const Text(
                              'Select a color first',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sizesForSelectedColor.map((String size) {

                                final bool isSelected = _selectedSize == size;
                                final bool isAvailable = _isSizeAvailable(size);
                                final bool isReserved = _isSizeReserved(size);

                                return GestureDetector(
                                  onTap: () {

                                    // if fully reserved → show error popup
                                    if (isReserved == true) {
                                      _showReservedError();
                                      return;
                                    }

                                    // if no stock at all → do nothing
                                    if (isAvailable == false) {
                                      return;
                                    }

                                    // otherwise select it
                                    setState(() {
                                      _selectedSize = size;
                                      _quantity = 1;
                                    });
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [

                                      // size chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : isReserved
                                                  ? const Color(0xFFFEF2F2)
                                                  : isAvailable
                                                      ? Colors.white
                                                      : const Color(0xFFF3F4F6),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF2563EB)
                                                : isReserved
                                                    ? const Color(0xFFFCA5A5)
                                                    : const Color(0xFFD1D5DB),
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          size,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? Colors.white
                                                : isReserved
                                                    ? const Color(0xFFDC2626)
                                                    : isAvailable
                                                        ? const Color(0xFF374151)
                                                        : const Color(0xFFD1D5DB),
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            decoration: isAvailable == false &&
                                                    isReserved == false
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),

                                      // reserved badge — small lock icon
                                      // shown on top-right corner of chip
                                      if (isReserved == true)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFDC2626),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.lock,
                                              size: 9,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                      const SizedBox(height: 8),

                      // legend for size chip colors
                      if (_selectedColor != null)
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildLegendItem(
                              color: const Color(0xFF374151),
                              label: 'Available',
                            ),
                            _buildLegendItem(
                              color: const Color(0xFFDC2626),
                              label: 'Reserved',
                            ),
                            _buildLegendItem(
                              color: const Color(0xFFD1D5DB),
                              label: 'Out of stock',
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // ── QUANTITY ──
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [

                          // decrease button
                          _buildQtyButton(
                            icon: Icons.remove,
                            onTap: () {
                              if (_quantity > 1) {
                                setState(() => _quantity--);
                              }
                            },
                          ),

                          // quantity display
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),

                          // increase button — capped at availableQty
                          _buildQtyButton(
                            icon: Icons.add,
                            onTap: () {
                              if (_quantity < maxQty) {
                                setState(() => _quantity++);
                              }
                            },
                          ),

                          // max available hint
                          if (variant != null && variant.availableQty > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                'Max: ${variant.availableQty}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── BOTTOM BUTTONS ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [

                // cancel
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // add to cart — disabled if not selected or fully reserved
                ElevatedButton(
                  onPressed: (
                    _selectedColor != null &&
                    _selectedSize != null &&
                    variant != null &&
                    variant.availableQty > 0
                  )
                      ? () {
                          widget.onAddToCart(
                            _selectedColor!,
                            _selectedSize!,
                            _quantity,
                            variant.retailPrice,
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBFDBFE),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // STOCK INFO ROW
  // label on left, value on right
  // ================================================
  Widget _buildStockRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ================================================
  // LEGEND ITEM
  // small colored dot + label
  // ================================================
  Widget _buildLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ================================================
  // QUANTITY BUTTON
  // ================================================
  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD1D5DB)),
          color: Colors.white,
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF374151)),
      ),
    );
  }
}