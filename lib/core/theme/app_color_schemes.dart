import 'package:material_ui/material_ui.dart';

/// Light and dark color schemes.
///
/// Accent roles (primary, secondary, tertiary, error) are generated from
/// one brand seed with the fidelity variant, which keeps the seed's
/// saturation: primary is a deep teal.
///
/// Surfaces are set by hand to near-neutral greys. Seeded surfaces carry
/// the brand hue, which made the page, cards, fields and bars all tints of
/// the same lavender; with neutral surfaces teal is left for what it
/// should mark: primary actions, selection and the hero.
///
/// Use surfaces by depth:
///   surface                  page background
///   surfaceContainerLow      cards (with AppPalette.cardBorder)
///   surfaceContainer         solid bars (the fallback for glass)
///   surfaceContainerHigh     text fields, chips, neutral icon circles
///   surfaceContainerHighest  progress tracks, keypad keys
///   surfaceContainerLowest   deepest well in dark mode; white in light
///
/// secondaryContainer / onSecondaryContainer are the selection colors
/// (navigation indicator, selected chips and segments): a teal tint.
abstract final class AppColorSchemes {
  static const Color seed = Color(0xFF0E5A64);

  static final ColorScheme light = ColorScheme.fromSeed(
    seedColor: seed,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    surface: const Color(0xFFF5F5F7),
    surfaceDim: const Color(0xFFD9D9DF),
    surfaceBright: const Color(0xFFFFFFFF),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFFFFFF),
    surfaceContainer: const Color(0xFFEFEFF2),
    surfaceContainerHigh: const Color(0xFFE9E9EE),
    surfaceContainerHighest: const Color(0xFFE1E1E7),
    onSurface: const Color(0xFF17181C),
    onSurfaceVariant: const Color(0xFF484954),
    outline: const Color(0xFF767783),
    outlineVariant: const Color(0xFFC9CAD3),
    secondaryContainer: const Color(0xFFD3ECEF),
    onSecondaryContainer: const Color(0xFF0A3F47),
    inverseSurface: const Color(0xFF2B2C33),
    onInverseSurface: const Color(0xFFF1F1F5),
  );

  static final ColorScheme dark = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    surface: const Color(0xFF0E0F12),
    surfaceDim: const Color(0xFF0E0F12),
    surfaceBright: const Color(0xFF35363E),
    surfaceContainerLowest: const Color(0xFF090A0C),
    surfaceContainerLow: const Color(0xFF17181D),
    surfaceContainer: const Color(0xFF1C1D23),
    surfaceContainerHigh: const Color(0xFF25262D),
    surfaceContainerHighest: const Color(0xFF303139),
    onSurface: const Color(0xFFE5E5EA),
    onSurfaceVariant: const Color(0xFFC4C5CF),
    outline: const Color(0xFF8E8F9A),
    outlineVariant: const Color(0xFF43444D),
    secondaryContainer: const Color(0xFF103E45),
    onSecondaryContainer: const Color(0xFFC6EEF2),
    inverseSurface: const Color(0xFFE5E5EA),
    onInverseSurface: const Color(0xFF2B2C33),
  );
}
