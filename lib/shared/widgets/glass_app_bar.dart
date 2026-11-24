import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import 'glass_surface.dart';

/// The app bar for screens whose content scrolls under it.
///
/// At the top of the page it is transparent, so the title sits directly on
/// the page. Once content scrolls under it, it turns to frosted glass with
/// a hairline along its bottom edge.
///
/// Use it with `Scaffold(extendBodyBehindAppBar: true)` and pad the
/// scrollable with [ScreenInsets], so the first row starts below the bar.
class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;

  /// Which scroll notifications count; by default those of the screen's
  /// own scrollable, not ones nested inside it.
  final ScrollNotificationPredicate notificationPredicate;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification ||
        !widget.notificationPredicate(notification)) {
      return;
    }
    final metrics = notification.metrics;
    final bool under;
    switch (metrics.axisDirection) {
      case AxisDirection.down:
        under = metrics.extentBefore > 0;
      case AxisDirection.up:
        under = metrics.extentAfter > 0;
      case AxisDirection.left:
      case AxisDirection.right:
        return;
    }
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return AppBar(
      title: widget.title,
      leading: widget.leading,
      actions: widget.actions,
      bottom: widget.bottom,
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      // The glass below is the background.
      backgroundColor: Colors.transparent,
      notificationPredicate: widget.notificationPredicate,
      flexibleSpace: TweenAnimationBuilder<double>(
        tween: Tween(end: _scrolledUnder ? 1 : 0),
        duration: animate ? Motion.medium : Duration.zero,
        curve: Motion.standard,
        builder: (context, t, _) => GlassSurface(
          solidColor: scheme.surface,
          intensity: t,
          border: Border(bottom: BorderSide(color: palette.glassBorder)),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
