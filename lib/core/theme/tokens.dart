import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Spacing scale. Use these for padding, gaps and margins instead of raw
/// numbers, so screens share one rhythm.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal inset of screen content from the display edge.
  static const double screen = lg;

  /// Bottom space a scrollable leaves so a floating action button never
  /// covers its last item (56dp button + 16dp margin + 16dp air).
  static const double fabClearance = 88;
}

/// Corner radius scale.
abstract final class Radii {
  /// Chips, small badges, progress bars.
  static const double sm = 8;

  /// Buttons, text fields, list tile icons.
  static const double md = 12;

  /// Cards and sheets' inner groups.
  static const double lg = 20;

  /// Hero cards, bottom sheets, dialogs.
  static const double xl = 28;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(xl));
}

/// Motion durations and curves. Keep UI transitions within 150–250ms.
abstract final class Motion {
  /// Small state changes: chip selection, toggles, pressed states.
  static const Duration fast = Duration(milliseconds: 150);

  /// Most transitions: switching content, expanding, fading.
  static const Duration medium = Duration(milliseconds: 200);

  /// Larger moves: sheets, page-level changes, the hero count-up.
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

/// Fixed component sizes.
abstract final class Sizes {
  /// Minimum touch target (Material and WCAG guidance).
  static const double touchTarget = 48;

  /// Tinted circle behind category and account icons.
  static const double iconCircle = 40;
  static const double iconCircleSmall = 32;
  static const double icon = 20;

  /// Height of budget and category progress bars.
  static const double progressBar = 8;
}
