import 'package:flutter/material.dart';

// ================================================
// PRODUCT REPLACEMENT CARD
// Shows discontinued products with AI replacements
// ================================================
class ProductReplacementCard extends StatelessWidget {

  final List<Map<String, dynamic>> replacements;
  final bool isLoading;

  const ProductReplacementCard({
    super.key,
    required this.replacements,
    this.isLoading = false,
  });

  // ── AI BADGE ──
  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: Color(0xFF7C3AED)),
          SizedBox(width: 4),
          Text(
            'AI Powered',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Product Replacement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              _buildAiBadge(),
            ],
          ),

          const SizedBox(height: 16),

          // ── LOADING ──
          if (isLoading)
            const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED),
                  strokeWidth: 2,
                ),
              ),
            )

          // ── EMPTY ──
          else if (replacements.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No replacement suggestions available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )

          // ── REPLACEMENT LIST ──
          else
            for (int i = 0; i < replacements.length; i = i + 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < replacements.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF3F4F6)),
                        )
                      : null,
                ),
                child: Row(
                  children: [

                    // discontinued product
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DISCONTINUED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replacements[i]['discontinuedProduct'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // arrow
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),

                    // recommended product
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replacements[i]['recommendedReplacement'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

          // ── AI NOTE ──
          if (replacements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AI analyzes sales trends and customer preferences to suggest optimal replacements for discontinued products.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF5B21B6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}