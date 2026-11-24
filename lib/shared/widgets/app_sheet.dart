import 'package:material_ui/material_ui.dart';

/// Shows a modal bottom sheet with a drag handle.
///
/// Use this instead of [showModalBottomSheet] so every sheet opens the
/// same way. Its color, shape and handle come from the theme.
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
    // Above everything, the bottom navigation included. Tab content runs
    // under that bar, so a sheet on the tab's own navigator would be cut
    // off by it.
    useRootNavigator: true,
    showDragHandle: true,
    builder: builder,
  );
}
