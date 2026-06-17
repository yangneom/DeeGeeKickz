import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

/// Single product row shown in search results list.
/// Tapping calls [onTap] to navigate to product detail.
class SearchResultTile extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final String query; // used to highlight matched text

  const SearchResultTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
        ),
        child: Row(
          children: [
            // ── Product image ─────────────────────────────────
            Container(
              width: 72,
              height: 72,
              color: const Color(0xFFEEEEEE),
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shopping_bag_outlined,
                  size: 28,
                  color: Color(0xFF656464),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Product details ───────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name with query highlight
                  _HighlightedText(
                    text: product.name,
                    query: query,
                    baseStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    highlightStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      backgroundColor: Color(0xFFE2E2E2),
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Brand · Category
                  Text(
                    '${product.brand}  ·  ${product.category}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF656464),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Price row
                  Row(
                    children: [
                      Text(
                        product.price > 0
                            ? product.formattedPrice
                            : 'Coming Soon',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      if (product.isDiscounted && product.originalPrice != null)
                        ...[
                        const SizedBox(width: 8),
                        Text(
                          product.formattedOriginalPrice,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF656464),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          color: Colors.black,
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Stock status
                      if (!product.inStock)
                        const Text(
                          'SOLD OUT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBA1A1A),
                          ),
                        ),

                      // Badge
                      if (product.badge != null && product.inStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFCFC4C5)),
                          ),
                          child: Text(
                            product.badge!.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF656464),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 20, color: Color(0xFFCFC4C5)),
          ],
        ),
      ),
    );
  }
}

// ─── Highlighted text helper ──────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: baseStyle);

    final lower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    final index = lower.indexOf(queryLower);

    if (index == -1) return Text(text, style: baseStyle);

    return RichText(
      text: TextSpan(
        children: [
          if (index > 0)
            TextSpan(text: text.substring(0, index), style: baseStyle),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: highlightStyle,
          ),
          if (index + query.length < text.length)
            TextSpan(
              text: text.substring(index + query.length),
              style: baseStyle,
            ),
        ],
      ),
    );
  }
}