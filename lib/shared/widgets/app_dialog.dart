import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// The app's alert dialog: a title, a message and actions. Takes the same three arguments as [AlertDialog]; show it with
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
    );
  }
}
