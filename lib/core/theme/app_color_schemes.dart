import 'package:flutter/material.dart';

/// Light and dark color schemes, generated from one brand seed so both
/// modes stay in sync.
///
/// The fidelity variant keeps the seed's saturation: primary is a rich
/// indigo (#4648D4 light, #C0C1FF dark) and primaryContainer stays close
/// to the brand #6366F1. The default tonal-spot variant would wash the
/// brand out to a grey violet.
///
/// Surfaces come from the scheme's neutral tones. Use them by depth:
///   surface                  page background
///   surfaceContainerLow      cards
///   surfaceContainer         grouped rows inside a card, nav bar
///   surfaceContainerHigh     text fields, chips, pressed rows
///   surfaceContainerHighest  progress tracks, skeletons
///   surfaceContainerLowest   deepest well; raised cards use AppPalette.raisedSurface
abstract final class AppColorSchemes {
  static const Color seed = Color(0xFF6366F1);

  static final ColorScheme light = ColorScheme.fromSeed(
    seedColor: seed,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  static final ColorScheme dark = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
}
