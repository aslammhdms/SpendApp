import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// A bar pinned to the bottom of a screen for its main action (Save).
///
/// Use it as the Scaffold's `bottomNavigationBar`. It keeps [child] clear
/// of the system gesture area.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
            Space.lg, Space.md, Space.lg, Space.md),
        child: child,
      ),
    );
  }
}
