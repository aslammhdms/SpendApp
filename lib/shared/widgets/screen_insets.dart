import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// Padding for a scrollable that runs under the glass bars.
///
/// Content scrolls behind the app bar and the bottom navigation, so the
/// scrollable itself fills the screen and its padding is what keeps the
/// first and last rows clear of the bars when it is scrolled to either end.
///
/// Use it on screens whose `Scaffold` has `extendBodyBehindAppBar: true`,
/// and call it with the context that builds that Scaffold (the screen's own
/// `context`), not one from inside the Scaffold's body: inside the body the
/// app bar is already counted, and it would be added twice.
abstract final class ScreenInsets {
  /// Padding for the screen's main scrollable. [top] and [bottom] are the
  /// space wanted between the bars and the content; pass
  /// [Space.fabClearance] as [bottom] on screens with a floating button.
  /// [appBarBottom] is the height of the app bar's `bottom` widget, if any.
  static EdgeInsets of(
    BuildContext context, {
    double horizontal = Space.screen,
    double top = Space.sm,
    double bottom = Space.lg,
    double appBarBottom = 0,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      topOf(context, appBarBottom: appBarBottom) + top,
      horizontal,
      bottomOf(context) + bottom,
    );
  }

  /// Height of what covers the top of the body: the status bar and the app
  /// bar. Also where a pull-to-refresh spinner should appear.
  static double topOf(BuildContext context, {double appBarBottom = 0}) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + appBarBottom;

  /// Height of what covers the bottom of the body: the navigation bar on a
  /// tab, otherwise the system gesture area.
  static double bottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;
}
