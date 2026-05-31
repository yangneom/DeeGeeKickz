import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// ================================================
// SALES TREND CARD
//
// Line chart showing actual vs predicted sales
// AI Powered by Groq
// ================================================
class SalesTrendCard extends StatelessWidget {

  // actual monthly sales data
  final List<double> actualSales;

  // predicted sales from Groq AI
  final List<double> predictedSales;

  // month labels
  final List<String> months;

  // AI insight message
  final String aiInsight;

  // is AI loading
  final bool isLoading;

  const SalesTrendCard({
    super.key,
    required this.actualSales,
    required this.predictedSales,
    required this.months,
    required this.aiInsight,
    this.isLoading = false,
  });

  // ================================================
  // BUILD AI BADGE
  // ================================================
  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: Color(0xFF7C3AED),
          ),
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

  // ================================================
  // BUILD LEGEND ROW
  // ================================================
  Widget _buildLegend() {
    return Row(
      children: [

        // actual sales legend
        Row(
          children: [
            Container(
              width: 20,
              height: 2,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 6),
            const Text(
              'Actual Sales',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        // predicted sales legend
        Row(
          children: [
            Container(
              width: 20,
              height: 2,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF7C3AED),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Predicted Sales',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    // combine actual + predicted for chart
    final List<FlSpot> actualSpots = [];
    final List<FlSpot> predictedSpots = [];

    for (int i = 0; i < actualSales.length; i++) {
      actualSpots.add(FlSpot(i.toDouble(), actualSales[i]));
    }

    // predicted starts where actual ends
    final int startIndex = actualSales.length - 1;
    for (int i = 0; i < predictedSales.length; i++) {
      predictedSpots.add(
        FlSpot(
          (startIndex + i).toDouble(),
          predictedSales[i],
        ),
      );
    }

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
                'Sales Trend Prediction',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              _buildAiBadge(),
            ],
          ),

          const SizedBox(height: 20),

          // ── CHART ──
          isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                      strokeWidth: 2,
                    ),
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
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF3F4F6),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value >= 1000000) {
                                return Text(
                                  '₱${(value / 1000000).toStringAsFixed(1)}M',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                );
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
                                  child: Text(
                                    months[index],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [

                        // actual sales line — solid blue
                        LineChartBarData(
                          spots: actualSpots,
                          isCurved: true,
                          color: const Color(0xFF2563EB),
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: const Color(0xFF2563EB),
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF2563EB).withOpacity(0.05),
                          ),
                        ),

                        // predicted sales line — purple dashed
                        LineChartBarData(
                          spots: predictedSpots,
                          isCurved: true,
                          color: const Color(0xFF7C3AED),
                          barWidth: 2.5,
                          dashArray: [6, 4],
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: const Color(0xFF7C3AED),
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF7C3AED).withOpacity(0.05),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

          const SizedBox(height: 12),

          // ── LEGEND ──
          _buildLegend(),

          const SizedBox(height: 16),

          // ── AI INSIGHT ──
          if (aiInsight.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Insight: $aiInsight',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B21B6),
                      ),
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