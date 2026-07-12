import 'package:flutter/material.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';

class AiTrendingCard extends StatelessWidget {
  final List<Map<String, dynamic>> trendingShoes;
  final bool isLoading;

  const AiTrendingCard({super.key, required this.trendingShoes, this.isLoading = false});

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
              DashboardTheme.cardTitle('AI Trending Shoes'),
              DashboardTheme.aiBadge(),
            ],
          ),

          const SizedBox(height: 16),

          if (isLoading)
            const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: DashboardTheme.aiPrimary, strokeWidth: 2)))
          else if (trendingShoes.isEmpty)
            const SizedBox(height: 120, child: Center(child: Text('No trending data available', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))))
          else
            for (int i = 0; i < trendingShoes.length; i = i + 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < trendingShoes.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trendingShoes[i]['productName'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                          const SizedBox(height: 2),
                          Text('${trendingShoes[i]['salesCount']} sold recently', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: DashboardTheme.successSurface, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up, size: 12, color: DashboardTheme.success),
                          const SizedBox(width: 4),
                          Text('+${trendingShoes[i]['growthPercent']}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DashboardTheme.success)),
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