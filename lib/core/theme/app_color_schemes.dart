import 'package:material_ui/material_ui.dart';

/// Light and dark color schemes.
///
/// Every role comes from one seed color, the Material way: the accents
/// carry the seed, and the surfaces are greys with a trace of its hue. The
/// brand seed is a deep teal. With "Use wallpaper colours" on, the seed is
/// the phone's wallpaper color instead ([fromWallpaper]).
///
/// Use surfaces by depth:
///   surface                  page background
///   surfaceContainerLow      cards and list items
///   surfaceContainer         bars: navigation, app bar once scrolled
///   surfaceContainerHigh     text fields, chips, neutral icon circles
///   surfaceContainerHighest  progress tracks, keypad keys
///
/// The generated tones are assigned to those jobs by [_assign], so cards
/// stand out from the page by tone alone, without borders or shadows: in
/// light mode the page is a soft grey and cards are the brightest tone; in
/// dark mode the page is the darkest tone and cards are a step lighter.
///
/// secondaryContainer / onSecondaryContainer are the selection colors
/// (navigation indicator, selected chips).
abstract final class AppColorSchemes {
  static const Color seed = Color(0xFF0E5A64);

  static final ColorScheme light = _brand(Brightness.light);
  static final ColorScheme dark = _brand(Brightness.dark);

  /// The fidelity variant keeps the seed's saturation, so primary stays a
  /// deep teal.
  static ColorScheme _brand(Brightness brightness) =>
      _assign(ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ));

  static ColorScheme _assign(ColorScheme s) =>
      s.brightness == Brightness.light
          ? s.copyWith(
              surface: s.surfaceContainer,
              surfaceContainerLow: s.surfaceContainerLowest,
              surfaceContainer: s.surfaceContainerHigh,
              surfaceContainerHigh: s.surfaceContainerHighest,
              surfaceContainerHighest: s.surfaceDim,
            )
          : s.copyWith(surfaceContainerLow: s.surfaceContainer);

  /// A scheme built on the phone's wallpaper color.
  static ColorScheme fromWallpaper(Color wallpaper, Brightness brightness) =>
      _assign(
          ColorScheme.fromSeed(seedColor: wallpaper, brightness: brightness));
}
