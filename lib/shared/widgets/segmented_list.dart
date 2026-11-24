import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// A group of list rows drawn as separate tiles with a hairline gap: the
/// group's outer corners are large and the corners between rows are small.
///
/// Use it in place of a [Card] around rows that each do something on tap.
class SegmentedList extends StatelessWidget {
  const SegmentedList({super.key, required this.children});

  final List<Widget> children;

  static const double gap = 2;
  static const Radius _outer = Radius.circular(Radii.lg);
  static const Radius _inner = Radius.circular(Radii.xs);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerLow;
    final last = children.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i <= last; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          Material(
            color: color,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? _outer : _inner,
                bottom: i == last ? _outer : _inner,
              ),
            ),
            child: children[i],
          ),
        ],
      ],
    );
  }
}
