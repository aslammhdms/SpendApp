import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../core/theme/tokens.dart';

/// The app's "pick one of a few" control: equal segments in a rounded
/// track, with a rounded block that slides to the selected one.
///
/// Used for the period on Analytics. The type tabs on Add Transaction are a
/// [TabBar] styled to the same shape, so the two read as one control.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Value and label of each segment, in order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Height of the track. Each segment is tappable over the full height,
  /// which keeps the touch target at 48dp.
  static const double height = Sizes.touchTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = segments.keys.toList();
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    final animate = !MediaQuery.disableAnimationsOf(context);
    // -1 is the first segment, 1 the last.
    final x = values.length == 1 ? 0.0 : -1 + 2 * index / (values.length - 1);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: Radii.mdAll,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: AnimatedAlign(
              alignment: Alignment(x, 0),
              duration: animate ? Motion.medium : Duration.zero,
              curve: Motion.standard,
              child: FractionallySizedBox(
                widthFactor: 1 / values.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: Radii.smAll,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final value in values)
                Expanded(
                  child: _Segment(
                    label: segments[value]!,
                    selected: value == selected,
                    onTap: () {
                      if (value == selected) return;
                      HapticFeedback.selectionClick();
                      onChanged(value);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
