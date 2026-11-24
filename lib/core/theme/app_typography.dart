import 'package:material_ui/material_ui.dart';

/// Type scale for the app, set in Roboto Flex (bundled in
/// assets/fonts/roboto_flex, so it renders the same offline).
///
/// Sizes follow the Material 3 roles with the Expressive emphasis: big,
/// heavy display and headline styles for amounts and screen titles, and
/// semibold titles and labels. Display and headline styles are also set a
/// little wider, which the variable font allows.
///
/// No colors are set here: ThemeData fills them from the ColorScheme, so
/// the same scale works in light and dark.
abstract final class AppTypography {
  static const String fontFamily = 'Roboto Flex';

  /// The second font file, holding the currency signs and accented letters
  /// that the first leaves out.
  static const List<String> fontFamilyFallback = ['Roboto Flex Ext'];

  /// Roboto Flex's digits are fixed-width by default, so amounts line up
  /// in columns and do not jitter while a number animates. The feature is
  /// still requested, for the fonts a device falls back to.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static List<FontVariation> _axes(double weight, [double width = 100]) => [
        FontVariation('wght', weight),
        FontVariation('wdth', width),
      ];

  static TextStyle _style(
    double size,
    double height,
    FontWeight weight, {
    double spacing = 0,
    double width = 100,
  }) =>
      TextStyle(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        fontVariations: _axes(weight.value.toDouble(), width),
        letterSpacing: spacing,
      );

  static const double _wide = 112;

  static final TextTheme textTheme = TextTheme(
    // Hero amount on Home.
    displayMedium:
        _style(45, 52, FontWeight.w800, spacing: -1, width: _wide),
    // Amount entry, summary cards.
    displaySmall:
        _style(36, 44, FontWeight.w800, spacing: -0.8, width: _wide),
    headlineLarge:
        _style(32, 40, FontWeight.w700, spacing: -0.5, width: _wide),
    // Large amounts: loan totals. Titles of top-level screens.
    headlineMedium:
        _style(28, 36, FontWeight.w700, spacing: -0.4, width: _wide),
    headlineSmall: _style(24, 32, FontWeight.w700, spacing: -0.2),
    // Screen titles in app bars.
    titleLarge: _style(22, 28, FontWeight.w600),
    // Card and section titles.
    titleMedium: _style(16, 24, FontWeight.w600, spacing: 0.1),
    // List tile titles.
    titleSmall: _style(14, 20, FontWeight.w600, spacing: 0.1),
    bodyLarge: _style(16, 24, FontWeight.w400, spacing: 0.2),
    bodyMedium: _style(14, 20, FontWeight.w400, spacing: 0.2),
    // Secondary lines: dates, notes, captions.
    bodySmall: _style(12, 16, FontWeight.w400, spacing: 0.3),
    // Buttons.
    labelLarge: _style(14, 20, FontWeight.w600, spacing: 0.1),
    // Chips, nav labels, badges.
    labelMedium: _style(12, 16, FontWeight.w600, spacing: 0.3),
    // Overlines and section headers ("TODAY").
    labelSmall: _style(11, 16, FontWeight.w600, spacing: 0.5),
  );

  /// [style] with tabular figures, for every money amount.
  static TextStyle money(TextStyle style) =>
      style.copyWith(fontFeatures: tabular);
}

extension MoneyTextStyle on TextStyle {
  /// This style with tabular figures, for money amounts.
  TextStyle get tabular => AppTypography.money(this);
}
