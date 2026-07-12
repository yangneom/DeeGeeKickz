import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';

// ================================================
// SALES TREND CARD
// ================================================
class SalesTrendCard extends StatelessWidget {
  final List<double> actualSales;
  final List<double> predictedSales;
  final List<String> months;
  final String aiInsight;
  final bool isLoading;

  const SalesTrendCard({
    super.key,
    required this.actualSales,
    required this.predictedSales,
    required this.months,
    required this.aiInsight,
    this.isLoading = false,
  });

  Widget _buildLegend() {
    return Row(
      children: [
        Row(
          children: [
            Container(width: 20, height: 3, decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            const Text('Actual Sales', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Container(
              width: 20,
              height: 2,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DashboardTheme.aiPrimary, width: 2, style: BorderStyle.solid)),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Predicted Sales', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> actualSpots = [];
    final List<FlSpot> predictedSpots = [];

    for (int i = 0; i < actualSales.length; i++) {
      actualSpots.add(FlSpot(i.toDouble(), actualSales[i]));
    }

    final int startIndex = actualSales.isNotEmpty ? actualSales.length - 1 : 0;
    for (int i = 0; i < predictedSales.length; i++) {
      predictedSpots.add(FlSpot((startIndex + i).toDouble(), predictedSales[i]));
    }

    return Container(
      padding: DashboardTheme.cardPadding,
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DashboardTheme.cardTitle('Sales Trend Prediction'),
              DashboardTheme.aiBadge(),
            ],
          ),

          const SizedBox(height: 20),

          isLoading || actualSpots.isEmpty
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(color: DashboardTheme.aiPrimary, strokeWidth: 2)
                        : const Text('No sales data yet', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 500000,
                        getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value >= 1000000) {
                                return Text('₱${(value / 1000000).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)));
                              }
                              if (value >= 1000) {
                                return Text('₱${(value / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < months.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(months[index], style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: actualSpots,
                          isCurved: true,
                          color: const Color(0xFF2563EB),
                          barWidth: 2.5,
                          dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: const Color(0xFF2563EB), strokeWidth: 0)),
                          belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withOpacity(0.05)),
                        ),
                        if (predictedSpots.isNotEmpty)
                          LineChartBarData(
                            spots: predictedSpots,
                            isCurved: true,
                            color: DashboardTheme.aiPrimary,
                            barWidth: 2.5,
                            dashArray: [6, 4],
                            dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: DashboardTheme.aiPrimary, strokeWidth: 0)),
                            belowBarData: BarAreaData(show: true, color: DashboardTheme.aiPrimary.withOpacity(0.05)),
                          ),
                      ],
                    ),
                  ),
                ),

          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 16),

          if (aiInsight.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashboardTheme.aiSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DashboardTheme.aiBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: DashboardTheme.aiPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('AI Insight: $aiInsight', style: const TextStyle(fontSize: 12, color: Color(0xFF5B21B6))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}