import 'package:flutter/material.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';

class ProductReplacementCard extends StatelessWidget {
  final List<Map<String, dynamic>> replacements;
  final bool isLoading;

  const ProductReplacementCard({super.key, required this.replacements, this.isLoading = false});

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
              DashboardTheme.cardTitle('Product Replacement'),
              DashboardTheme.aiBadge(),
            ],
          ),

          const SizedBox(height: 16),

          if (isLoading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: DashboardTheme.aiPrimary, strokeWidth: 2)))
          else if (replacements.isEmpty)
            const SizedBox(height: 200, child: Center(child: Text('No archived products need a replacement suggestion', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))))
          else
            for (int i = 0; i < replacements.length; i = i + 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < replacements.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ARCHIVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(replacements[i]['discontinuedProduct'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF9CA3AF)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RECOMMENDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: DashboardTheme.success, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(replacements[i]['recommendedReplacement'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DashboardTheme.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

          if (replacements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: DashboardTheme.aiSurface, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'AI searches the web for the closest current replacement, restricted to your existing brand lineup.',
                style: TextStyle(fontSize: 11, color: Color(0xFF5B21B6)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}