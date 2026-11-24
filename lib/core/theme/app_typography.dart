import 'package:material_ui/material_ui.dart';

/// Type scale for the app, set in Inter (bundled in assets/fonts/inter, so
/// it renders the same offline).
///
/// Sizes follow the Material 3 roles, tightened for a dense finance UI.
/// No colors are set here: ThemeData fills them from the ColorScheme, so
/// the same scale works in light and dark.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  /// Tabular (fixed-width) digits, so amounts line up in columns and do
  /// not jitter while a number animates.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextTheme textTheme = TextTheme(
    // Hero amount on Home and summary cards.
    displaySmall: TextStyle(
      fontSize: 36,
      height: 44 / 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    // Large amounts: amount entry, loan totals.
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    // Screen titles in app bars.
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    // Card and section titles.
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    // List tile titles.
    titleSmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
    ),
    // Secondary lines: dates, notes, captions.
    bodySmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
    ),
    // Buttons.
    labelLarge: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    ),
    // Chips, nav labels, badges.
    labelMedium: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
    // Overlines and section headers ("TODAY").
    labelSmall: TextStyle(
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    ),
  );

  /// [style] with tabular figures, for every money amount.
  static TextStyle money(TextStyle style) =>
      style.copyWith(fontFeatures: tabular);
}

extension MoneyTextStyle on TextStyle {
  /// This style with tabular figures, for money amounts.
  TextStyle get tabular => AppTypography.money(this);
}
