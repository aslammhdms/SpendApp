import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';

/// What a glass surface carries, which decides how see-through it may be.
enum GlassLevel {
  /// App bar, bottom navigation, pinned action bars: neutral text and icons.
  bar,

  /// Sheets, dialogs and menus: any content, including colored text.
  sheet,
}

/// A frosted-glass background for surfaces that float over content.
///
/// It blurs what is behind it and lays a tint on top; [child] is drawn on
/// that. The blur strength and tint opacities are the [Glass] tokens.
///
/// Rules for using it:
///  * Only on layered surfaces (bars, sheets, dialogs, menus). Cards,
///    lists, charts and forms stay solid.
///  * It only looks like glass when content passes behind it, so the
///    scrollable must extend under the surface.
///  * Never inside a scrolling list item, and never one glass surface on
///    top of another: each one re-reads and blurs the pixels behind it.
///
/// Draws [solidColor] with no blur when the system asks for high contrast
/// ([MediaQuery.highContrastOf]) or when [Glass.enabled] is off. Flutter
/// has no "reduce transparency" setting to read; high contrast is the
/// closest signal it exposes.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.solidColor,
    this.level = GlassLevel.bar,
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.intensity = 1,
    this.child,
  });

  /// The surface's ordinary color, used when glass is off.
  final Color solidColor;
  final GlassLevel level;

  /// The blur is clipped to this shape, so it covers no more than the
  /// surface itself.
  final BorderRadius borderRadius;

  /// Hairline on the edges that face the content, usually one side in
  /// `context.palette.glassBorder`.
  final BoxBorder? border;

  /// 0 draws nothing, 1 the full effect; in between it fades in. Used by
  /// the app bar, which turns to glass as content scrolls under it.
  final double intensity;

  final Widget? child;

  /// Whether glass surfaces are drawn solid in this context.
  static bool isSolid(BuildContext context) =>
      !Glass.enabled || MediaQuery.highContrastOf(context);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = intensity.clamp(0.0, 1.0);

    if (isSolid(context)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: solidColor.withValues(alpha: solidColor.a * t),
            border: t == 0 ? null : border,
          ),
          child: child,
        ),
      );
    }

    final (tint, opacity) = switch (level) {
      GlassLevel.bar => (palette.glassBarTint, Glass.barTintOpacity),
      GlassLevel.sheet => (palette.glassSheetTint, Glass.sheetTintOpacity),
    };
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: opacity * t),
        border: t == 0 ? null : border,
      ),
      child: child,
    );
    // Nothing to blur yet: skip the filter rather than run it at zero.
    if (t == 0) return content;

    final filter = ImageFilter.blur(
      sigmaX: Glass.blurSigma * t,
      sigmaY: Glass.blurSigma * t,
    );
    // One plain BackdropFilter per surface, clipped to the surface.
    // BackdropFilter.grouped could share a single backdrop read between
    // the app bar and the navigation bar; it is not used because its
    // benefit could not be measured without a device.
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(filter: filter, child: content),
    );
  }
}
