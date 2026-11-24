import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

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

  /// Cards, bottom sheets, dialogs.
  static const double xl = 28;

  /// The Home hero.
  static const double xxl = 36;

  /// Inner corners of connected shapes: neighbours in a button group or a
  /// segmented list.
  static const double xs = 4;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(xl));
}

/// Motion. Things that move or change shape use a spring with a little
/// overshoot ([spatial]); fades and color changes use one without
/// ([effects]). Pair each curve with its duration.
abstract final class Motion {
  /// Small state changes: chip selection, toggles, pressed states.
  static const Duration fast = Duration(milliseconds: 200);

  /// Most transitions: switching content, expanding, fading.
  static const Duration medium = Duration(milliseconds: 350);

  /// Larger moves: sheets, page-level changes.
  static const Duration slow = Duration(milliseconds: 500);

  /// Count-up of the hero amount on Home. Longer than a transition so the
  /// number reads as settling, and skipped when animations are disabled.
  static const Duration countUp = Duration(milliseconds: 700);

  /// Material 3 Expressive springs (stiffness and damping ratio from the
  /// specification's motion tokens).
  static final Curve spatial = SpringCurve(stiffness: 380, dampingRatio: 0.8);
  static final Curve spatialFast =
      SpringCurve(stiffness: 800, dampingRatio: 0.6);
  static final Curve effects = SpringCurve(stiffness: 1600, dampingRatio: 1);

  /// Position, size and shape changes.
  static final Curve standard = spatial;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

/// A spring from rest at 0 to rest at 1, as a [Curve]. The spring's own
/// settling time is stretched over the animation's duration, so durations
/// near that time (a few hundred milliseconds) look natural.
class SpringCurve extends Curve {
  SpringCurve({required double stiffness, required double dampingRatio})
      : _simulation = SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: stiffness,
            ratio: dampingRatio,
          ),
          0,
          1,
          0,
        ) {
    // The first moment after which the spring stays within 0.1% of rest.
    var settled = 0.0;
    for (var t = 0.0; t < 3; t += 0.005) {
      if ((_simulation.x(t) - 1).abs() > 0.001) settled = t + 0.005;
    }
    _settleTime = settled;
  }

  final SpringSimulation _simulation;
  late final double _settleTime;

  @override
  double transformInternal(double t) => _simulation.x(t * _settleTime);
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
