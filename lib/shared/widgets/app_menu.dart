import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// One entry of a [AppMenuButton].
@immutable
class AppMenuItem<T> {
  const AppMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Drawn in the error color (Delete).
  final bool destructive;
}

/// An icon button that opens a small menu next to the button, placed so it
/// stays on screen.
class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    required this.tooltip,
    this.icon = Icons.more_vert,
  });

  final List<AppMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;

  Future<void> _open(BuildContext context) async {
    // The root navigator, so the menu can extend over the bottom navigation.
    final navigator = Navigator.of(context, rootNavigator: true);
    final button = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero),
          ancestor: overlay),
    );
    final value = await navigator.push(_AppMenuRoute<T>(
      anchor: anchor,
      items: items,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ));
    if (value != null) onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: () => _open(context),
    );
  }
}

class _AppMenuRoute<T> extends PopupRoute<T> {
  _AppMenuRoute({
    required this.anchor,
    required this.items,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<AppMenuItem<T>> items;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => Motion.fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final animate = !media.disableAnimations;
    Widget menu = _AppMenu<T>(items: items);
    if (animate) {
      menu = ScaleTransition(
        alignment: Alignment.topRight,
        scale: CurvedAnimation(parent: animation, curve: Motion.standard)
            .drive(Tween(begin: 0.92, end: 1)),
        child: menu,
      );
    }
    return CustomSingleChildLayout(
      delegate: _MenuLayout(anchor: anchor, safeArea: media.padding),
      child: menu,
    );
  }
}

/// Places the menu just below the button with their right edges aligned,
/// or above it when there is no room below, and keeps it on screen.
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({required this.anchor, required this.safeArea});

  final Rect anchor;
  final EdgeInsets safeArea;

  static const _margin = Space.sm;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(Size(
      constraints.maxWidth - 2 * _margin,
      constraints.maxHeight - safeArea.vertical - 2 * _margin,
    ));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = size.width - childSize.width - _margin;
    final x = (anchor.right - childSize.width).clamp(_margin, maxX);
    final minY = safeArea.top + _margin;
    final maxY = size.height - safeArea.bottom - childSize.height - _margin;
    var y = anchor.bottom;
    if (y > maxY) y = anchor.top - childSize.height;
    return Offset(x.toDouble(), y.clamp(minY, maxY < minY ? minY : maxY));
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor || safeArea != oldDelegate.safeArea;
}

class _AppMenu<T> extends StatelessWidget {
  const _AppMenu({required this.items});

  final List<AppMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: MaterialLocalizations.of(context).popupMenuLabel,
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 3,
        shadowColor: scheme.shadow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        child: IntrinsicWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              _buildItem(context, item, theme),
          ],
        ),
      ),
    ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    AppMenuItem<T> item,
    ThemeData theme,
  ) {
    final color = item.destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.pop(context, item.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: Sizes.touchTarget,
            minWidth: 160,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: Sizes.icon, color: color),
                  const SizedBox(width: Space.md),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
