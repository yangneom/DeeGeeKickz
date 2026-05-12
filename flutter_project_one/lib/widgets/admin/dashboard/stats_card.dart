import 'package:flutter/material.dart';

// ================================================
// STATS CARD
//
// This is one of the 5 cards at the top of
// the dashboard.
//
// Example:
// ┌─────────────────────┐
// │ 🛒  Pending Orders  │
// │      5              │
// │ View details →      │
// └─────────────────────┘
//
// Each card needs:
//   - icon
//   - icon background color
//   - icon color
//   - title
//   - count (the big number)
//   - onTap (when user clicks view details)
// ================================================
class StatsCard extends StatelessWidget {

  // the icon to show (example: Icons.shopping_cart)
  final IconData icon;

  // background color of the icon circle
  final Color iconBackgroundColor;

  // color of the icon itself
  final Color iconColor;

  // title of the card (example: 'Pending Orders')
  final String title;

  // the big number (example: 5)
  final int count;

  // color of the big number
  final Color countColor;

  // what happens when user clicks view details
  final VoidCallback onTap;

  const StatsCard({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.countColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        children: [

          // ── TOP ROW — icon + title ──
          Row(
            children: [

              // icon inside a colored circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 12),

              // title text
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── BIG NUMBER ──
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: countColor,
            ),
          ),

          const SizedBox(height: 12),

          // ── VIEW DETAILS LINK ──
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: const [
                Text(
                  'View details',
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
    );
  }
}