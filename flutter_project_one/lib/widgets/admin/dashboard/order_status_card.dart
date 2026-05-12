import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// ================================================
// ORDER STATUS CARD
//
// Shows a donut chart of order statuses
//
// ┌─────────────────────────────┐
// │ Order Status Overview       │
// │                             │
// │      [donut chart]          │
// │         38                  │
// │      Total Orders           │
// │                             │
// │ ● Pending        5          │
// │ ● Confirmed      3          │
// │ ● Preparing      4          │
// │ ● Shipped        6          │
// │ ● Completed     18          │
// │ ● Cancelled      2          │
// └─────────────────────────────┘
// ================================================
class OrderStatusCard extends StatelessWidget {

  // order counts per status
  final int pending;
  final int confirmed;
  final int preparing;
  final int shipped;
  final int completed;
  final int cancelled;

  // what happens when user clicks view all
  final VoidCallback onViewAll;

  const OrderStatusCard({
    super.key,
    required this.pending,
    required this.confirmed,
    required this.preparing,
    required this.shipped,
    required this.completed,
    required this.cancelled,
    required this.onViewAll,
  });

  // ================================================
  // BUILD ONE LEGEND ROW
  // example: ● Pending    5
  // ================================================
  Widget _buildLegendRow(
    String label,
    int count,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [

          // colored dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 8),

          // label
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // count
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // calculate total orders
    int totalOrders = pending + confirmed +
        preparing + shipped + completed + cancelled;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ← add this
        children: [

          // ── HEADER ROW ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              // title with icon
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Order Status Overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),

              // view all link
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  children: const [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── DONUT CHART ──
          SizedBox(
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [

                // the donut chart itself
                PieChart(
                  PieChartData(
                    // hole in the middle
                    centerSpaceRadius: 50,

                    // no touch effect
                    sectionsSpace: 2,

                    sections: [

                      // pending — orange
                      PieChartSectionData(
                        value: pending.toDouble(),
                        color: const Color(0xFFF59E0B),
                        radius: 30,
                        showTitle: false,
                      ),

                      // confirmed — blue
                      PieChartSectionData(
                        value: confirmed.toDouble(),
                        color: const Color(0xFF2563EB),
                        radius: 30,
                        showTitle: false,
                      ),

                      // preparing — purple
                      PieChartSectionData(
                        value: preparing.toDouble(),
                        color: const Color(0xFF7C3AED),
                        radius: 30,
                        showTitle: false,
                      ),

                      // shipped — cyan
                      PieChartSectionData(
                        value: shipped.toDouble(),
                        color: const Color(0xFF0891B2),
                        radius: 30,
                        showTitle: false,
                      ),

                      // completed — green
                      PieChartSectionData(
                        value: completed.toDouble(),
                        color: const Color(0xFF16A34A),
                        radius: 30,
                        showTitle: false,
                      ),

                      // cancelled — red
                      PieChartSectionData(
                        value: cancelled.toDouble(),
                        color: const Color(0xFFEF4444),
                        radius: 30,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),

                // total number in the middle
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Text(
                      totalOrders.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Text(
                      'Total Orders',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── LEGEND ──
          _buildLegendRow('Pending', pending,
              const Color(0xFFF59E0B)),
          _buildLegendRow('Confirmed', confirmed,
              const Color(0xFF2563EB)),
          _buildLegendRow('Preparing', preparing,
              const Color(0xFF7C3AED)),
          _buildLegendRow('Shipped', shipped,
              const Color(0xFF0891B2)),
          _buildLegendRow('Completed', completed,
              const Color(0xFF16A34A)),
          _buildLegendRow('Cancelled', cancelled,
              const Color(0xFFEF4444)),
        ],
      ),
    );
  }
}