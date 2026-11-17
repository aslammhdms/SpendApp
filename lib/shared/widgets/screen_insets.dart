import 'package:flutter/widgets.dart';
import '../../core/theme/tokens.dart';

/// Padding for a scrollable that runs under the glass bars.
///
/// Content scrolls behind the app bar and the bottom navigation, so the
/// scrollable itself fills the screen and its padding is what keeps the
/// first and last rows clear of the bars when it is scrolled to either end.
///
/// The bars' heights come from [MediaQuery.paddingOf], which the enclosing
/// scaffolds set, so call this with a context inside the scaffold's body
/// (the `context` of a [Builder] or of a child widget, not the one that
/// built the scaffold).
abstract final class ScreenInsets {
  /// [top] and [bottom] are the space wanted between the bars and the
  /// content. Pass [Space.fabClearance] as [bottom] on screens with a
  /// floating button.
  static EdgeInsets of(
    BuildContext context, {
    double horizontal = Space.screen,
    double top = Space.sm,
    double bottom = Space.lg,
  }) {
    final bars = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      horizontal,
      bars.top + top,
      horizontal,
      bars.bottom + bottom,
    );
  }

  /// Height of what covers the bottom of the body (the navigation bar, or
  /// the system gesture area), to add to a scrollable's bottom padding.
  static double bottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  /// Distance from the top of the body to the bottom of the app bar, for
  /// things that must appear below it (a pull-to-refresh spinner).
  static double topOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top;
}
