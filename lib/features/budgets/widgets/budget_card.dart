import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/budget.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/app_menu.dart';

class BudgetCard extends StatelessWidget {
  final Budget budget;
  final String? categoryIcon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String currency;

  const BudgetCard({
    super.key,
    required this.budget,
    this.categoryIcon,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final percentUsed = budget.percentUsed.clamp(0.0, 1.5);
    final progressColor = palette.budgetColor(percentUsed);
    final remaining = budget.remaining;
    final percentLabel = '${(percentUsed * 100).toStringAsFixed(0)}%';
    final spent =
        CurrencyUtils.format(budget.spentAmount, currencyCode: currency);
    final limit = CurrencyUtils.format(budget.amount, currencyCode: currency);
    final remainingLabel = remaining >= 0
        ? '${CurrencyUtils.format(remaining, currencyCode: currency)} left'
        : '${CurrencyUtils.format(remaining.abs(), currencyCode: currency)} over';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.lg,
            Space.sm,
            Space.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (categoryIcon != null) ...[
                    CategoryIcon(emoji: categoryIcon!, color: progressColor),
                    const SizedBox(width: Space.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(budget.name, style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          _getPeriodLabel(budget.period),
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AppMenuButton<String>(
                    tooltip: 'Budget options',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    items: const [
                      AppMenuItem(
                        value: 'edit',
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                      ),
                      AppMenuItem(
                        value: 'delete',
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        destructive: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.only(right: Space.lg - Space.sm),
                child: Semantics(
                  label: CurrencyUtils.spoken(
                      '$percentLabel used, $spent of $limit, $remainingLabel'),
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(spent, style: text.titleLarge?.tabular),
                          const SizedBox(width: Space.xs),
                          Expanded(
                            child: Text(
                              'of $limit',
                              style: text.bodySmall?.tabular
                                  .copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.sm),
                      TweenAnimationBuilder<double>(
                        tween:
                            Tween(begin: 0, end: percentUsed.clamp(0.0, 1.0)),
                        duration: Motion.slow,
                        curve: Motion.standard,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          color: progressColor,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: progressColor.withValues(alpha: 0.14),
                              borderRadius: Radii.smAll,
                            ),
                            child: Text(
                              percentLabel,
                              style: text.labelMedium?.tabular.copyWith(
                                color: progressColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            remainingLabel,
                            style: text.bodySmall?.tabular.copyWith(
                              color: remaining >= 0
                                  ? scheme.onSurfaceVariant
                                  : palette.budgetDanger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPeriodLabel(BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.weekly:
        return 'Weekly budget';
      case BudgetPeriod.monthly:
        return 'Monthly budget';
      case BudgetPeriod.yearly:
        return 'Yearly budget';
    }
  }
}
