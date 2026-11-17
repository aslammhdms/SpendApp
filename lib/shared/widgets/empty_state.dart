import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

/// Placeholder for a screen or card with nothing to show yet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// Smaller version for use inside a card.
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final circle = compact ? 48.0 : 72.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Space.xl : Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: circle * 0.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compact ? Space.md : Space.lg),
            Text(
              title,
              style: (compact ? text.titleSmall : text.titleMedium)
                  ?.copyWith(color: scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                subtitle!,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Space.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
