import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// ================================================
// BRAND PERFORMANCE CARD
// Pie chart showing sales by brand
// No AI — just data from Supabase later
// ================================================
class BrandPerformanceCard extends StatelessWidget {

  final List<BrandData> brands;

  const BrandPerformanceCard({
    super.key,
    required this.brands,
  });

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
          const Text(
            'Brand Performance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 20),

          // ── PIE CHART ──
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: brands.map((brand) {
                      return PieChartSectionData(
                        value: brand.percentage,
                        color: brand.color,
                        radius: 60,
                        showTitle: true,
                        title: '${brand.percentage.toInt()}%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── LEGEND ──
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: brands.map((brand) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: brand.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    brand.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ================================================
// BRAND DATA MODEL
// ================================================
class BrandData {
  final String name;
  final double percentage;
  final Color color;

  BrandData({
    required this.name,
    required this.percentage,
    required this.color,
  });
}