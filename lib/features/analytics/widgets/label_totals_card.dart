import 'package:material_ui/material_ui.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';

/// Spending by label in the period, largest first. Tapping a label opens its
/// transactions.
class LabelTotalsCard extends StatelessWidget {
  const LabelTotalsCard({
    super.key,
    required this.labelTotals,
    required this.currency,
    required this.onOpenLabel,
  });

  final Map<String, double> labelTotals;
  final String currency;
  final ValueChanged<String> onOpenLabel;

  static const int _shown = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final entries = labelTotals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();
    final largest = entries.first.value;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('By label'),
          const SizedBox(height: Space.xs),
          for (final entry in entries.take(_shown))
            InkWell(
              onTap: () => onOpenLabel(entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xl,
                  vertical: Space.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sell_outlined,
                            size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        MoneyText(
                          entry.value,
                          currency: currency,
                          style: text.titleSmall,
                        ),
                        const SizedBox(width: Space.xs),
                        Icon(Icons.chevron_right,
                            size: 20, color: scheme.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    ClipRRect(
                      borderRadius: Radii.smAll,
                      child: LinearProgressIndicator(
                        value: largest > 0 ? entry.value / largest : 0,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHigh,
                        color: scheme.primary,
                        semanticsLabel: '${entry.key} share',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.md),
        ],
      ),
    );
  }
}
