import 'package:flutter/material.dart';

/// Nike-inspired design tokens for DeeGeeKickz.
///
/// Philosophy (matches nike.com / Nike app):
/// - Near-monochrome base (black / white / warm greys) with a single
///   accent reserved for sale/urgency states, not decoration.
/// - Bold condensed display type (Archivo Narrow) for headlines,
///   clean grotesque (Inter) for body/UI, both already used ad hoc
///   across your widgets — this file just centralizes the values so
///   home, shop, and product screens stay visually consistent.
/// - Sharp corners (radius 0) on buttons/chips/cards — Nike rarely
///   rounds anything except pills (e.g. size chips), which is why
///   AppRadius has both `sharp` and `pill`.
/// - Generous whitespace, high-contrast CTAs (solid black fill,
///   white on hover/press is inverted — see AppColors.invertOnPress
///   pattern already used in your _CategoryTile/_DropCard hover code).
class AppColors {
  AppColors._();

  static const Color primary = Colors.black;
  static const Color onPrimary = Colors.white;

  static const Color background = Color(0xFFF9F9F9);
  static const Color surfaceContainerLow = Color(0xFFF3F3F4);

  static const Color outline = Color(0xFFCFC4C5);
  static const Color outlineStrong = Color(0xFF7E7576);

  static const Color textSecondary = Color(0xFF5F5E5E);
  static const Color textMuted = Color(0xFF656464);
  static const Color textFaint = Color(0xFF4C4546);

  // Reserved for sale badges / out-of-stock / low-stock states only —
  // never used decoratively, matching Nike's restrained use of red.
  static const Color alert = Color(0xFFBA1A1A);
}

class AppRadius {
  AppRadius._();
  static const double sharp = 0;
  static const double pill = 999;
}

class AppTypography {
  AppTypography._();

  static const String display = 'Archivo Narrow';
  static const String body = 'Inter';

  // Section headline, e.g. "TRENDING NOW" — desktop size.
  static const TextStyle headlineLgDesktop = TextStyle(
    fontFamily: display,
    fontSize: 48,
    height: 52 / 48,
    letterSpacing: -0.48,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  // Section headline — mobile size.
  static const TextStyle headlineLgMobile = TextStyle(
    fontFamily: display,
    fontSize: 32,
    height: 36 / 32,
    letterSpacing: -0.32,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle labelButton = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

/// Grayscale-to-color hover/press filter used across product & category
/// tiles (Hero, FeaturedCategories, TrendingProducts, NewDrops). Pulled
/// out here so every tile uses the exact same matrix instead of four
/// separate copy-pasted const declarations drifting out of sync.
const ColorFilter appGrayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      error: AppColors.alert,
    ),
    fontFamily: AppTypography.body,
    dividerColor: AppColors.outline,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sharp),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: AppTypography.labelButton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sharp),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: AppTypography.labelButton,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sharp),
      ),
      side: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.outline,
      thumbColor: AppColors.primary,
      overlayColor: Colors.black12,
      trackHeight: 2,
    ),
  );
}