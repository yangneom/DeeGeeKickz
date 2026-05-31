import 'package:flutter/material.dart';

// ================================================
// AI TRENDING SHOES CARD
// Shows top trending shoes from Groq AI
// ================================================
class AiTrendingCard extends StatelessWidget {

  final List<Map<String, dynamic>> trendingShoes;
  final bool isLoading;

  const AiTrendingCard({
    super.key,
    required this.trendingShoes,
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
                'AI Trending Shoes',
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
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED),
                  strokeWidth: 2,
                ),
              ),
            )

          // ── EMPTY ──
          else if (trendingShoes.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No trending data available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )

          // ── TRENDING SHOES LIST ──
          else
            for (int i = 0; i < trendingShoes.length; i = i + 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < trendingShoes.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF3F4F6)),
                        )
                      : null,
                ),
                child: Row(
                  children: [

                    // product name + sales
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trendingShoes[i]['productName'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${trendingShoes[i]['salesCount']} sales this month',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // growth badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.trending_up,
                            size: 12,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${trendingShoes[i]['growthPercent']}%',
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
        ],
      ),
    );
  }
}