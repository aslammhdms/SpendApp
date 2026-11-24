import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/goal.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/wavy_progress_bar.dart';

/// A savings goal with its progress.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.currency,
    this.onTap,
    this.compact = false,
  });

  final Goal goal;
  final String currency;
  final VoidCallback? onTap;

  /// Leaves out the monthly figure, for the Home card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    String money(double v) => CurrencyUtils.format(v, currencyCode: currency);
    final percent = (goal.progress * 100).floor();
    final barColor = goal.isReached ? palette.budgetSafe : scheme.primary;

    String? hint;
    if (goal.isReached) {
      hint = 'Goal reached';
    } else if (!compact) {
      final monthly = goal.monthlyToReach(DateTime.now());
      final date = goal.targetDate;
      if (monthly != null && date != null) {
        hint = '${money(monthly)} a month to reach it by '
            '${DateFormat('MMM y').format(date)}';
      } else if (date != null) {
        hint = 'Target date ${DateFormat('d MMM y').format(date)} has passed';
      }
    }

    final body = Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CategoryIcon(emoji: goal.icon, color: Color(goal.color)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${money(goal.savedAmount)} of '
                      '${money(goal.targetAmount)}',
                      style:
                          text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text('$percent%', style: text.titleSmall),
            ],
          ),
          const SizedBox(height: Space.md),
          WavyProgressBar(
            value: goal.progress,
            color: barColor,
            semanticsLabel: '${goal.name} progress',
            semanticsValue: '$percent percent',
          ),
          if (hint != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              hint,
              style: text.bodySmall?.copyWith(
                color: goal.isReached ? palette.budgetSafe : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) {
      return InkWell(onTap: onTap, child: body);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}
