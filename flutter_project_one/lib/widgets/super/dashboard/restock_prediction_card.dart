import 'package:flutter/material.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';

class RestockPredictionCard extends StatelessWidget {
  final List<Map<String, dynamic>> restockItems;
  final bool isLoading;

  const RestockPredictionCard({super.key, required this.restockItems, this.isLoading = false});

  Widget _buildStockBar(int current, int max) {
    double percentage = max > 0 ? current / max : 0;
    Color barColor;
    if (percentage <= 0.15) {
      barColor = DashboardTheme.danger;
    } else if (percentage <= 0.30) {
      barColor = DashboardTheme.warning;
    } else {
      barColor = DashboardTheme.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Stock Level', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            Text('$current/$max', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: percentage.clamp(0, 1), backgroundColor: const Color(0xFFE5E7EB), valueColor: AlwaysStoppedAnimation<Color>(barColor), minHeight: 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DashboardTheme.cardPadding,
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DashboardTheme.cardTitle('Restock Prediction'),
              DashboardTheme.aiBadge(),
            ],
          ),

          const SizedBox(height: 16),

          if (isLoading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: DashboardTheme.aiPrimary, strokeWidth: 2)))
          else if (restockItems.isEmpty)
            const SizedBox(height: 200, child: Center(child: Text('No restock predictions — stock levels look healthy', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))))
          else
            for (int i = 0; i < restockItems.length; i = i + 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < restockItems.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: DashboardTheme.aiPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(restockItems[i]['productName'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStockBar(restockItems[i]['currentStock'] ?? 0, restockItems[i]['maxStock'] ?? 100),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Stockout in ${restockItems[i]['daysUntilStockout']} days', style: const TextStyle(fontSize: 11, color: DashboardTheme.danger, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text('Restock: ${restockItems[i]['recommendedRestock']} units', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
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