import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../core/theme/tokens.dart';

/// The app's "pick one of a few" control: a connected button group.
///
/// Equal buttons sit side by side with a small gap. The group's outer
/// corners are fully round and the corners between neighbours are small;
/// the selected button fills with color and rounds all its corners.
///
/// Used for the period on Analytics and the type on Add Transaction.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.selectedColor,
    this.selectedForeground,
  });

  /// Value and label of each segment, in order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Fill and text color of the selected button; the primary color and its
  /// "on" color when null.
  final Color? selectedColor;
  final Color? selectedForeground;

  /// Height of the group, which keeps each touch target at 48dp.
  static const double height = Sizes.touchTarget;

  static const double _gap = 2;
  static const Radius _round = Radius.circular(height / 2);
  static const Radius _inner = Radius.circular(Radii.sm);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = segments.keys.toList();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(
              child: _Segment(
                label: segments[values[i]]!,
                selected: values[i] == selected,
                radius: values[i] == selected
                    ? const BorderRadius.all(_round)
                    : BorderRadiusDirectional.horizontal(
                        start: i == 0 ? _round : _inner,
                        end: i == values.length - 1 ? _round : _inner,
                      ).resolve(Directionality.of(context)),
                selectedColor: selectedColor ?? scheme.primary,
                selectedForeground: selectedForeground ?? scheme.onPrimary,
                onTap: () {
                  if (values[i] == selected) return;
                  HapticFeedback.selectionClick();
                  onChanged(values[i]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.radius,
    required this.selectedColor,
    required this.selectedForeground,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final BorderRadius radius;
  final Color selectedColor;
  final Color selectedForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: TweenAnimationBuilder<BorderRadius?>(
        // The corners spring between connected and fully round.
        tween: BorderRadiusTween(end: radius),
        duration: animate ? Motion.medium : Duration.zero,
        curve: Motion.spatialFast,
        builder: (context, animated, child) {
          final shape = RoundedRectangleBorder(
            borderRadius: (animated ?? radius)
                .clamp(BorderRadius.zero, const BorderRadius.all(_round)),
          );
          return Material(
            color: selected ? selectedColor : scheme.surfaceContainerHigh,
            shape: shape,
            animationDuration: animate ? Motion.fast : Duration.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: child),
          );
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? selectedForeground : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Radius _round = SegmentedControl._round;
}

extension on BorderRadius {
  /// Keeps a spring's overshoot from producing a negative radius.
  BorderRadius clamp(BorderRadius min, BorderRadius max) => BorderRadius.only(
        topLeft: Radius.circular(topLeft.x.clamp(min.topLeft.x, max.topLeft.x)),
        topRight:
            Radius.circular(topRight.x.clamp(min.topRight.x, max.topRight.x)),
        bottomLeft: Radius.circular(
            bottomLeft.x.clamp(min.bottomLeft.x, max.bottomLeft.x)),
        bottomRight: Radius.circular(
            bottomRight.x.clamp(min.bottomRight.x, max.bottomRight.x)),
      );
}
