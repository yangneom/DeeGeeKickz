import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../models/discount_model.dart';
import '../../../screens/customer/product_detail/product_detail.dart';

/// Product card backed by the real [Product] model from Supabase.
/// Pass [discount] (from DiscountService.fetchActiveDiscountsByProduct())
/// to show a strikethrough original price + sale price + "SALE" badge.
class ShopProductCard extends StatelessWidget {
  final Product product;
  final Discount? discount;
  final VoidCallback? onTap;

  const ShopProductCard({
    super.key,
    required this.product,
    this.discount,
    this.onTap,
});

void _navigateToDetail(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductDetailScreen(product: product),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.totalAvailable == 0;
    final String? imageUrl = product.variants.isNotEmpty
        ? product.variants.first.primaryImageUrl
        : null;

    // Use lowest retail price across variants
    final double basePrice = product.variants.isEmpty
        ? 0
        : product.variants
            .map((v) => v.retailPrice)
            .reduce((a, b) => a < b ? a : b);

    // Apply the discount (if any) against this card's own base price,
    // rather than the admin-side originalPrice snapshot, so it stays
    // correct even if variant pricing has changed since the discount
    // was created.
    double? salePrice;
    if (discount != null) {
      if (discount!.discountType == 'Percentage') {
        salePrice = basePrice - (basePrice * (discount!.discountValue / 100));
      } else {
        salePrice = basePrice - discount!.discountValue;
      }
      if (salePrice < 0) salePrice = 0;
    }

    return GestureDetector(
      onTap: onTap ?? () => _navigateToDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image ─────────────────────────────────
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: isOutOfStock ? 0.5 : 1.0,
                  child: Container(
                    color: const Color(0xFFEEEEEE),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Color(0xFFCFC4C5),
                                size: 36,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFFCFC4C5),
                              size: 36,
                            ),
                          ),
                  ),
                ),

                // Badges
                if (isOutOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(label: 'SOLD OUT', color: const Color(0xFFBA1A1A)),
                  )
                else if (discount != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(
                      label: discount!.discountType == 'Percentage'
                          ? '-${discount!.discountValue.toStringAsFixed(0)}%'
                          : 'SALE',
                      color: const Color(0xFFBA1A1A),
                    ),
                  )
                // Matches the same threshold used for Admin's
                // low-stock notifications (stock_service.dart,
                // _lowStockThreshold = 5) — previously this badge
                // fired at 10, so a product could show "Low Stock"
                // to customers well before Admin even got alerted
                // about it.
                else if (product.totalAvailable <= 5)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(label: 'LOW STOCK', color: Colors.black),
                  ),
              ],
            ),
          ),

          // ── Info ──────────────────────────────────
          Opacity(
            opacity: isOutOfStock ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand · Category
                  Text(
                    '${product.brand} · ${product.category}'.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                      color: Color(0xFF4C4546),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Name
                  Text(
                    product.productName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Price
                  if (isOutOfStock)
                    const Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBA1A1A),
                      ),
                    )
                  else if (salePrice != null)
                    Row(
                      children: [
                        Text(
                          '₱${salePrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBA1A1A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₱${basePrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '₱${basePrice.toStringAsFixed(0)}+',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: color,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}