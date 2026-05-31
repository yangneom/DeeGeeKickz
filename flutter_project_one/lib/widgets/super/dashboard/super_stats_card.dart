import 'package:flutter/material.dart';

// ================================================
// SUPER STATS CARD
//
// Same pattern as admin StatsCard but with
// an extra subtitle/badge below the number
//
// ┌─────────────────────────┐
// │ 💰  Monthly Revenue     │
// │   ₱2,450,000            │
// │   +12.5% ↑              │
// └─────────────────────────┘
// ================================================
class SuperStatsCard extends StatelessWidget {

  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final String title;
  final String value;
  final String? badge;
  final Color? badgeColor;
  final bool isWarning;

  const SuperStatsCard({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.value,
    this.badge,
    this.badgeColor,
    this.isWarning = false,
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

          // ── TOP ROW — icon + title ──
          Row(
            children: [

              // icon container
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

              // title
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

          // ── VALUE ──
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 8),

          // ── BADGE ──
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isWarning
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: badgeColor ??
                      (isWarning
                          ? const Color(0xFF92400E)
                          : const Color(0xFF065F46)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}