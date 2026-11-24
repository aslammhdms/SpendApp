import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/constants/category_defaults.dart';
import 'package:spendsheet/core/theme/app_color_schemes.dart';
import 'package:spendsheet/core/theme/app_palette.dart';
import 'package:spendsheet/core/theme/tokens.dart';

/// WCAG 2 relative luminance of an opaque color.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2 contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What is seen where [tint] at [opacity] lies over [backdrop].
Color glassOver(Color tint, double opacity, Color backdrop) =>
    Color.alphaBlend(tint.withValues(alpha: opacity), backdrop);

const _textAA = 4.5;
const _iconAA = 3.0;

void main() {
  final themes = {
    'light': (AppColorSchemes.light, AppPalette.light(AppColorSchemes.light)),
    'dark': (AppColorSchemes.dark, AppPalette.dark(AppColorSchemes.dark)),
  };

  for (final MapEntry(key: name, value: (scheme, palette)) in themes.entries) {
    /// Everything that can pass behind glass: the two extremes, every
    /// color the app draws, and every color a category or account can be.
    final backdrops = <Color>[
      const Color(0xFF000000),
      const Color(0xFFFFFFFF),
      scheme.surface,
      scheme.surfaceContainerLow,
      scheme.onSurface,
      scheme.primary,
      scheme.error,
      palette.hero,
      ...palette.chart,
      palette.chartOther,
      palette.income,
      palette.expense,
      palette.loan,
      palette.budgetWarning,
      ...CategoryDefaults.pickerColors,
      for (final c in CategoryDefaults.expenseCategories) Color(c.color),
      for (final c in CategoryDefaults.incomeCategories) Color(c.color),
      for (final a in CategoryDefaults.defaultAccounts) Color(a.color),
    ];

    double worst(Color foreground, Color tint, double opacity) => backdrops
        .map((b) => contrast(foreground, glassOver(tint, opacity, b)))
        .reduce(math.min);

    group('$name theme', () {
      test('text and icons on glass bars meet AA over any backdrop', () {
        final text = {
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
        };
        // The sync indicator in the app bar.
        final icons = {
          'income': palette.income,
          'primary': scheme.primary,
          'error': scheme.error,
          'budgetWarning': palette.budgetWarning,
        };
        for (final e in text.entries) {
          expect(
            worst(e.value, palette.glassBarTint, Glass.barTintOpacity),
            greaterThanOrEqualTo(_textAA),
            reason: '${e.key} text on a glass bar',
          );
        }
        for (final e in icons.entries) {
          expect(
            worst(e.value, palette.glassBarTint, Glass.barTintOpacity),
            greaterThanOrEqualTo(_iconAA),
            reason: '${e.key} icon on a glass bar',
          );
        }
      });

      test('any text color on glass sheets meets AA over any backdrop', () {
        final text = {
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
          'primary': scheme.primary,
          'error': scheme.error,
          'income': palette.income,
          'expense': palette.expense,
          'loan': palette.loan,
          'budgetWarning': palette.budgetWarning,
        };
        for (final e in text.entries) {
          expect(
            worst(e.value, palette.glassSheetTint, Glass.sheetTintOpacity),
            greaterThanOrEqualTo(_textAA),
            reason: '${e.key} text on a glass sheet',
          );
        }
      });

      test('text colors meet AA on the solid surfaces they are used on', () {
        final surfaces = {
          'surface': scheme.surface,
          'surfaceContainerLow': scheme.surfaceContainerLow,
          'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'raisedSurface': palette.raisedSurface,
        };
        final text = {
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
          'primary': scheme.primary,
          'income': palette.income,
          'expense': palette.expense,
          'loan': palette.loan,
          'budgetWarning': palette.budgetWarning,
        };
        for (final s in surfaces.entries) {
          for (final t in text.entries) {
            expect(
              contrast(t.value, s.value),
              greaterThanOrEqualTo(_textAA),
              reason: '${t.key} on ${s.key}',
            );
          }
        }
      });

      test('selection colors meet AA', () {
        expect(
          contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(_textAA),
        );
        expect(
          contrast(scheme.onSurface, scheme.secondaryContainer),
          greaterThanOrEqualTo(_textAA),
        );
      });

      test('hero text meets AA on the hero color, chip hairline included',
          () {
        final lit = Color.alphaBlend(palette.heroGlow, palette.hero);
        for (final on in [palette.onHero, palette.onHeroMuted]) {
          expect(contrast(on, palette.hero), greaterThanOrEqualTo(_textAA));
          expect(contrast(on, lit), greaterThanOrEqualTo(_textAA));
        }
      });

      test('chart colors stand out from cards', () {
        for (final color in [...palette.chart, palette.chartOther]) {
          expect(
            contrast(color, scheme.surfaceContainerLow),
            greaterThanOrEqualTo(_iconAA),
          );
        }
      });
    });
  }
}
