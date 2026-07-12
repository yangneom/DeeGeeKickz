import 'package:flutter/material.dart';

// ================================================
// DASHBOARD THEME
// Shared visual constants for the Analytics Dashboard,
// used across all stat/insight cards for consistency.
// ================================================
class DashboardTheme {
  // Card container
  static BoxDecoration cardDecoration({Color? accentTop}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF111827).withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: const Color(0xFFF1F1F3)),
    );
  }

  static const EdgeInsets cardPadding = EdgeInsets.all(22);

  // AI accent (purple) — used for "AI Powered" badges + accents
  static const Color aiPrimary = Color(0xFF7C3AED);
  static const Color aiSurface = Color(0xFFF5F3FF);
  static const Color aiBorder = Color(0xFFDDD6FE);

  // Semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSurface = Color(0xFFFEE2E2);

  static Widget aiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: aiBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: aiPrimary),
          SizedBox(width: 5),
          Text(
            'AI Powered',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: aiPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget cardTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
        letterSpacing: -0.2,
      ),
    );
  }
}