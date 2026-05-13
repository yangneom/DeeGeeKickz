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
// Then taps "Add to Cart"
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

  // Currently selected color and size
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;

  // ================================================
  // GET UNIQUE COLORS from variants
  // ================================================
  List<String> get _uniqueColors {
    List<String> colors = [];
    for (ProductVariant v in widget.product.variants) {
      if (!colors.contains(v.color)) {
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
        .where((v) => v.color == _selectedColor)
        .map((v) => v.size)
        .toList();
  }

  // ================================================
  // GET SELECTED VARIANT
  // ================================================
  ProductVariant? get _selectedVariant {
    if (_selectedColor == null || _selectedSize == null) return null;
    try {
      return widget.product.variants.firstWhere(
        (v) => v.color == _selectedColor && v.size == _selectedSize,
      );
    } catch (_) {
      return null;
    }
  }

  // ================================================
  // IS SIZE AVAILABLE (has stock)
  // ================================================
  bool _isSizeAvailable(String size) {
    try {
      final variant = widget.product.variants.firstWhere(
        (v) => v.color == _selectedColor && v.size == size,
      );
      return variant.stockQty > 0;
    } catch (_) {
      return false;
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    final ProductVariant? variant = _selectedVariant;
    final double price = variant?.retailPrice ?? widget.product.averagePrice;
    final int maxQty = variant?.stockQty ?? 1;

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
                  ],
                ),

                const SizedBox(width: 20),

                // ── VARIANT SELECTORS ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Price
                      Text(
                        'Price  ₱${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                        children: _uniqueColors.map((color) {
                          final bool isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                                // Reset size when color changes
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

                      // Show size chips only when color is selected
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
                              children: _sizesForSelectedColor.map((size) {
                                final bool isSelected = _selectedSize == size;
                                final bool isAvailable =
                                    _isSizeAvailable(size);

                                return GestureDetector(
                                  onTap: isAvailable
                                      ? () {
                                          setState(() {
                                            _selectedSize = size;
                                            _quantity = 1;
                                          });
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : isAvailable
                                              ? Colors.white
                                              : const Color(0xFFF3F4F6),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF2563EB)
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
                                            : isAvailable
                                                ? const Color(0xFF374151)
                                                : const Color(0xFFD1D5DB),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        decoration: isAvailable
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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

                          // Increase button
                          _buildQtyButton(
                            icon: Icons.add,
                            onTap: () {
                              if (_quantity < maxQty) {
                                setState(() => _quantity++);
                              }
                            },
                          ),

                          // Quantity display
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

                          // Decrease button
                          _buildQtyButton(
                            icon: Icons.remove,
                            onTap: () {
                              if (_quantity > 1) {
                                setState(() => _quantity--);
                              }
                            },
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

                // Cancel
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),

                const SizedBox(width: 12),

                // Add to Cart
                ElevatedButton(
                  onPressed: (_selectedColor != null && _selectedSize != null)
                      ? () {
                          widget.onAddToCart(
                            _selectedColor!,
                            _selectedSize!,
                            _quantity,
                            variant!.retailPrice,
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBFDBFE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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