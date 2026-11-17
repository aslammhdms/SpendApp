import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/theme/tokens.dart';

/// Tracks whether a floating action button should show: hidden while the
/// user scrolls down through content, shown again when they scroll up.
///
/// Wrap the screen body in a `NotificationListener<UserScrollNotification>`
/// with [onScroll], and the button in an [AutoHideFab].
class FabVisibility extends ValueNotifier<bool> {
  FabVisibility() : super(true);

  bool onScroll(UserScrollNotification notification) {
    // Only react to the main vertical scrollable, not nested lists.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        value = false;
      case ScrollDirection.forward:
        value = true;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }
}

/// Slides [child] out of view while [visibility] is false.
class AutoHideFab extends StatelessWidget {
  const AutoHideFab({
    super.key,
    required this.visibility,
    required this.child,
  });

  final FabVisibility visibility;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      builder: (context, visible, child) => AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 2),
        duration: Motion.medium,
        curve: Motion.standard,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Motion.fast,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
      child: child,
    );
  }
}
