import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/budget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';

class BudgetProgressBars extends StatelessWidget {
  final List<Budget> budgets;
  final VoidCallback? onViewAll;
  final String currency;

  const BudgetProgressBars({
    super.key,
    required this.budgets,
    this.onViewAll,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final displayBudgets = budgets.take(3).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Budget Status',
            actionLabel: 'View All',
            onAction: budgets.length > 3 ? onViewAll : null,
          ),
          if (budgets.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No budgets set',
              compact: true,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.sm,
                Space.xl,
                Space.xl,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < displayBudgets.length; i++) ...[
                    if (i > 0) const SizedBox(height: Space.lg + 4),
                    _BudgetProgressItem(
                      budget: displayBudgets[i],
                      currency: currency,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetProgressItem extends StatelessWidget {
  final Budget budget;
  final String currency;

  const _BudgetProgressItem({
    required this.budget,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final percentUsed = budget.percentUsed.clamp(0.0, 1.5);
    final progressColor = context.palette.budgetColor(percentUsed);
    final percentLabel = '${(percentUsed * 100).toStringAsFixed(0)}%';
    final spent =
        CurrencyUtils.format(budget.spentAmount, currencyCode: currency);
    final limit = CurrencyUtils.format(budget.amount, currencyCode: currency);

    return Semantics(
      label: '${budget.name} budget, $percentLabel used, $spent of $limit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget.name,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                percentLabel,
                style: text.labelLarge?.tabular.copyWith(color: progressColor),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentUsed.clamp(0.0, 1.0)),
            duration: Motion.slow,
            curve: Motion.standard,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              color: progressColor,
            ),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$spent spent',
                  style: text.bodySmall?.tabular
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                'of $limit',
                style: text.bodySmall?.tabular
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
