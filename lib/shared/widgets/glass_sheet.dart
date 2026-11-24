import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import 'glass_surface.dart';

/// Shows a modal bottom sheet on frosted glass, with a drag handle.
///
/// Use this instead of [showModalBottomSheet] so every sheet looks the
/// same. The sheet stays solid when glass is switched off.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    // Above everything, the bottom navigation included. Tab content now
    // runs under that bar, so a sheet on the tab's own navigator would be
    // cut off by it.
    useRootNavigator: true,
    // The glass below is the sheet's background and carries the handle.
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return GlassSurface(
        level: GlassLevel.sheet,
        solidColor: scheme.surfaceContainerLow,
        borderRadius: Radii.sheetTop,
        border: Border(top: BorderSide(color: context.palette.glassBorder)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DragHandle(),
            Flexible(child: builder(context)),
          ],
        ),
      );
    },
  );
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Space.xl + Space.xs,
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: Radii.smAll,
          ),
        ),
      ),
    );
  }
}
