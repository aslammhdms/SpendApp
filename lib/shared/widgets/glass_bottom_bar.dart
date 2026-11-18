import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import 'glass_surface.dart';

/// A bar pinned to the bottom of a screen for its main action (Save), on
/// frosted glass with a hairline along the top.
///
/// Use it as the Scaffold's `bottomNavigationBar`. It keeps [child] clear
/// of the system gesture area.
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      solidColor: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: context.palette.glassBorder)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
            Space.lg, Space.md, Space.lg, Space.md),
        child: child,
      ),
    );
  }
}
