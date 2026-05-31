import 'package:flutter/material.dart';

// ================================================
// RESTOCK PREDICTION CARD
// Shows products that need restocking — AI Powered
// ================================================
class RestockPredictionCard extends StatelessWidget {

  final List<Map<String, dynamic>> restockItems;
  final bool isLoading;

  const RestockPredictionCard({
    super.key,
    required this.restockItems,
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

  // ── STOCK LEVEL BAR ──
  Widget _buildStockBar(int current, int max) {
    double percentage = max > 0 ? current / max : 0;

    Color barColor;
    if (percentage <= 0.15) {
      barColor = const Color(0xFFEF4444);
    } else if (percentage <= 0.30) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = const Color(0xFF16A34A);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Stock Level',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            Text(
              '$current/$max',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
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
                'Restock Prediction',
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
          else if (restockItems.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No restock predictions available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )

          // ── RESTOCK ITEMS LIST ──
          else
            for (int i = 0; i < restockItems.length; i = i + 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < restockItems.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF3F4F6)),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // product name
                    Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          restockItems[i]['productName'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // stock bar
                    _buildStockBar(
                      restockItems[i]['currentStock'] ?? 0,
                      restockItems[i]['maxStock'] ?? 100,
                    ),

                    const SizedBox(height: 8),

                    // stockout + restock info
                    Row(
                      children: [
                        Text(
                          'Stockout in ${restockItems[i]['daysUntilStockout']} days',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Restock: ${restockItems[i]['recommendedRestock']} units',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
