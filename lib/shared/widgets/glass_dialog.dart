import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import 'glass_surface.dart';

/// The app's alert dialog: a title, a message and actions on frosted
/// glass. Takes the same three arguments as [AlertDialog]; show it with
/// [showDialog].
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = theme.dialogTheme;

    return Dialog(
      // The glass below is the dialog's background.
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      child: GlassSurface(
        level: GlassLevel.sheet,
        solidColor: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Radii.xlAll,
        child: DecoratedBox(
          // Foreground border, so the hairline follows the rounded shape.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: Radii.xlAll,
            border: Border.all(color: context.palette.glassBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.xl, Space.xl, Space.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Semantics(
                    namesRoute: true,
                    container: true,
                    child: DefaultTextStyle.merge(
                      style: dialogTheme.titleTextStyle ??
                          theme.textTheme.titleLarge,
                      child: title!,
                    ),
                  ),
                if (title != null && content != null)
                  const SizedBox(height: Space.lg),
                if (content != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle.merge(
                        style: dialogTheme.contentTextStyle ??
                            theme.textTheme.bodyMedium,
                        child: content!,
                      ),
                    ),
                  ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  // Side by side when they fit, stacked when they do not
                  // (long labels, large text).
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: Space.sm,
                    overflowAlignment: OverflowBarAlignment.end,
                    overflowSpacing: Space.xs,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
