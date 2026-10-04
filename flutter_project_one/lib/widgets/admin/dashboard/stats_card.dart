import 'package:flutter/material.dart';

// ================================================
// STATS CARD
//
// One of the 5 cards at the top of the dashboard.
// The WHOLE card is clickable (instead of a small
// "View details" link), with a subtle chevron as the
// affordance.
//
// Example:
// ┌─────────────────────────┐
// │ 🛒  Pending Orders    › │
// │                         │
// │ 5                       │
// │ Awaiting your action    │
// └─────────────────────────┘
//
// Each card needs:
//   - icon
//   - icon background color
//   - icon color
//   - title
//   - count (the big number)
//   - countColor
//   - onTap (the whole card is the tap target)
//   - caption (optional one-line hint under the number)
// ================================================
class StatsCard extends StatelessWidget {

  // the icon to show (example: Icons.shopping_cart)
  final IconData icon;

  // background color of the icon tile
  final Color iconBackgroundColor;

  // color of the icon itself
  final Color iconColor;

  // title of the card (example: 'Pending Orders')
  final String title;

  // the big number (example: 5)
  final int count;

  // color of the big number
  final Color countColor;

  // what happens when the card is clicked
  final VoidCallback onTap;

  // optional short hint under the number (example: 'Awaiting action')
  final String? caption;

  const StatsCard({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.countColor,
    required this.onTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFF9FAFB),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TOP ROW — icon + title + chevron ──
              Row(
                children: [

                  // icon inside a tinted tile
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

                  // subtle "this card is clickable" hint
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFFD1D5DB),
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

              // ── CAPTION ──
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}