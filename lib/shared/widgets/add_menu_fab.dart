import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// What the Add menu offers. [query] is the `type` the Add Transaction
/// screen opens on.
enum AddChoice {
  expense('Expense', Icons.north_east_rounded, 'expense'),
  income('Income', Icons.south_west_rounded, 'income'),
  transfer('Transfer', Icons.swap_horiz_rounded, 'transfer'),
  loan('Loan', Icons.handshake_outlined, 'loan');

  const AddChoice(this.label, this.icon, this.query);

  final String label;
  final IconData icon;
  final String query;
}

/// The Add button of the main screens. Tapping it opens a menu above the
/// button, and the choice opens Add Transaction on that type.
class AddMenuFab extends StatelessWidget {
  const AddMenuFab({super.key});

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context, rootNavigator: true);
    final button = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero),
          ancestor: overlay),
    );
    final choice = await navigator.push(_AddMenuRoute(
      anchor: anchor,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ));
    if (choice != null && context.mounted) {
      context.push('/transactions/add?type=${choice.query}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _open(context),
      tooltip: 'Add transaction',
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }
}

class _AddMenuRoute extends PopupRoute<AddChoice> {
  _AddMenuRoute({required this.anchor, required this.barrierLabel});

  /// Where the Add button is, so the menu's close button covers it.
  final Rect anchor;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => const Color(0x52000000);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => Motion.medium;

  @override
  Duration get reverseTransitionDuration => Motion.fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final size = MediaQuery.sizeOf(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    const choices = AddChoice.values;

    return Stack(
      children: [
        Positioned(
          right: size.width - anchor.right,
          bottom: size.height - anchor.bottom,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'Add',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  _Entrance(
                    animation: animation,
                    // The item nearest the button arrives first.
                    order: choices.length - 1 - i,
                    count: choices.length,
                    animate: animate,
                    child: _MenuItem(choice: choices[i]),
                  ),
                  const SizedBox(height: Space.sm),
                ],
                const SizedBox(height: Space.xs),
                // The same size as the Add button, which it covers.
                SizedBox(
                  width: anchor.width,
                  height: anchor.height,
                  child: FloatingActionButton.extended(
                    heroTag: null,
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Springs a menu item up into place, each a moment after the one below.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.animation,
    required this.order,
    required this.count,
    required this.animate,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final int count;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return FadeTransition(opacity: animation, child: child);
    final start = 0.4 * order / count;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: Motion.spatialFast),
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Interval(start, (start + 0.4).clamp(0, 1)),
      ),
      child: ScaleTransition(
        alignment: Alignment.bottomRight,
        scale: Tween<double>(begin: 0.6, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.choice});

  final AddChoice choice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.primaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context, choice);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(choice.icon, color: scheme.onPrimaryContainer),
                const SizedBox(width: Space.md),
                Text(
                  choice.label,
                  style: text.titleMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
