import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';

class BrandPerformanceCard extends StatelessWidget {
  final List<BrandData> brands;

  const BrandPerformanceCard({super.key, required this.brands});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DashboardTheme.cardPadding,
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardTheme.cardTitle('Brand Performance'),
          const SizedBox(height: 20),

          if (brands.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(child: Text('No sales data yet', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
            )
          else
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: brands.map((brand) {
                    return PieChartSectionData(
                      value: brand.percentage,
                      color: brand.color,
                      radius: 58,
                      showTitle: true,
                      title: '${brand.percentage.toInt()}%',
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: brands.map((brand) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: brand.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(brand.name, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class BrandData {
  final String name;
  final double percentage;
  final Color color;

  BrandData({required this.name, required this.percentage, required this.color});
}