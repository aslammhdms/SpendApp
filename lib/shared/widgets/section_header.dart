import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// Title row of a card or list section, with an optional action on the
/// right ("View All") or any other [trailing] widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.sm, 0),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.touchTarget),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: text.titleMedium),
              ),
            ),
            if (trailing != null) trailing!,
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase label above a group of rows ("TODAY", "PEOPLE").
class OverlineHeader extends StatelessWidget {
  const OverlineHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding =
        const EdgeInsets.fromLTRB(Space.xs, Space.xl, Space.xs, Space.sm),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
