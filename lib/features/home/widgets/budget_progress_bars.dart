import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/budget.dart';

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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (onViewAll != null && budgets.length > 3)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),
          if (budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No budgets set',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: displayBudgets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final budget = displayBudgets[index];
                return _BudgetProgressItem(
                  budget: budget,
                  currency: currency,
                );
              },
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
    final percentUsed = budget.percentUsed.clamp(0.0, 1.5);
    final progressColor = _getProgressColor(percentUsed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                budget.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(percentUsed * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentUsed.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${CurrencyUtils.format(budget.spentAmount, currencyCode: currency)} spent',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
            Text(
              'of ${CurrencyUtils.format(budget.amount, currencyCode: currency)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getProgressColor(double percent) {
    if (percent >= 1.0) {
      return AppColors.budgetDanger;
    } else if (percent >= 0.8) {
      return AppColors.budgetWarning;
    } else {
      return AppColors.budgetSafe;
    }
  }
}
