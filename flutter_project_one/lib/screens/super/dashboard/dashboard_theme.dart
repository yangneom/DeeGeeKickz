import 'package:flutter/material.dart';

// ================================================
// DASHBOARD THEME
// Shared visual constants for the Analytics Dashboard,
// used across all stat/insight cards for consistency.
//
// UPDATE: flattened per design direction — no boxShadow, no
// "AI Powered" badge. Matches the plain bordered-card style used
// elsewhere in the app (e.g. Sales Report's Monthly Performance
// cards), rather than a separate "AI-flavored" visual language.
// aiBadge() is kept as a no-op-returning method (not deleted) so
// any call site that still references it doesn't break — it now
// just renders nothing.
// ================================================
class DashboardTheme {
  // Card container — flat, bordered, no shadow.
  static BoxDecoration cardDecoration({Color? accentTop}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );
  }

  static const EdgeInsets cardPadding = EdgeInsets.all(22);

  // Kept for any code still reading these colors for accents
  // (e.g. a "Suggest New Product" dialog) — just no longer used
  // for a purple badge on every card.
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

  // No-op — badge removed per design direction. Kept as a method
  // (not deleted) so existing call sites like
  // `DashboardTheme.aiBadge()` inside a Row don't need editing;
  // it just renders zero-size and disappears visually.
  static Widget aiBadge() {
    return const SizedBox.shrink();
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