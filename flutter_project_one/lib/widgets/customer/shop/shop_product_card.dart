import 'package:flutter/material.dart';

import '../../../models/product_model.dart';
import '../../../models/product_detail_model.dart';
import '../../../screens/customer/product_detail/product_detail.dart';

/// Product card — image on top, info below.
/// Passes discount info to ProductDetailScreen when the product is on promo.
class ShopProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ShopProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  void _navigateToDetail(BuildContext context) {
    final detail = mockProductDetails[product.id] ?? mockVortexApexV1;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: detail,
          // Pass discount info so the detail screen shows the sale UI
          discountPercent:
              product.isDiscounted ? product.discountPercent : null,
          originalPrice:
              product.isDiscounted ? product.originalPrice : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSoldOut = !product.inStock;

    return GestureDetector(
      onTap: onTap ?? () => _navigateToDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image ──────────────────────────────
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: isSoldOut ? 0.5 : 1.0,
                  child: Container(
                    color: const Color(0xFFEEEEEE),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFFCFC4C5),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),

                // Badge: discount % takes priority over regular badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: product.isDiscounted
                      ? _DiscountBadge(
                          percent: product.discountPercent!)
                      : product.badge != null
                          ? _Badge(
                              label: product.badge!,
                              isSoldOut: isSoldOut)
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ── Info ───────────────────────────────
          Opacity(
            opacity: isSoldOut ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand · Category
                  Text(
                    '${product.brand} · ${product.category}'
                        .toUpperCase(),
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
                    product.name.toUpperCase(),
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

                  // Price — discounted shows strikethrough original
                  if (product.isDiscounted)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          product.formattedOriginalPrice,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF7E7576),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFF7E7576),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Rating
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: Colors.black),
                      const SizedBox(width: 3),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ],
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

class _DiscountBadge extends StatelessWidget {
  final int percent;
  const _DiscountBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFFBA1A1A),
      child: Text(
        '-$percent%',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool isSoldOut;

  const _Badge({required this.label, required this.isSoldOut});

  @override
  Widget build(BuildContext context) {
    final isMember = label == 'Member Exclusive';
    final Color bg = isSoldOut
        ? const Color(0xFFBA1A1A)
        : isMember
            ? Colors.black
            : Colors.white;
    final Color fg =
        (isSoldOut || isMember) ? Colors.white : Colors.black;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: (isSoldOut || isMember)
            ? null
            : Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}