import 'package:flutter/material.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';

// ================================================
// SUPER STATS CARD
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
      padding: DashboardTheme.cardPadding,
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
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

          const SizedBox(height: 18),

          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 10),

          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isWarning ? DashboardTheme.warningSurface : DashboardTheme.successSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badgeColor ??
                      (isWarning ? const Color(0xFF92400E) : DashboardTheme.success),
                ),
              ),
            ),
        ],
      ),
    );
  }
}