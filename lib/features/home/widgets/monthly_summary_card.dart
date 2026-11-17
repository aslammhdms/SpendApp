import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/money_text.dart';

/// Hero card on Home: this month's net savings, with income and expense.
///
/// The headline amount is neutral; green and red are kept for the income
/// and expense signals underneath.
class MonthlySummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;
  final String currency;

  const MonthlySummaryCard({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final isSaving = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: Radii.xlAll,
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'This Month',
                  style:
                      text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm + 2,
                  vertical: Space.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: Radii.smAll,
                ),
                child: Text(
                  _getCurrentMonth(),
                  style: text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          AnimatedMoney(
            balance,
            currency: currency,
            semanticLabel: isSaving ? 'Net savings' : 'Over budget',
            style: text.displaySmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Space.xs),
          Text(
            isSaving ? 'Net savings' : 'Over budget',
            style: text.bodyMedium?.copyWith(
              color: isSaving ? scheme.onSurfaceVariant : palette.expense,
              fontWeight: isSaving ? null : FontWeight.w600,
            ),
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.south_west_rounded,
                  label: 'Income',
                  amount: income,
                  kind: MoneyKind.income,
                  iconColor: palette.income,
                  iconBackground: palette.incomeContainer,
                  currency: currency,
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.north_east_rounded,
                  label: 'Expense',
                  amount: expense,
                  kind: MoneyKind.expense,
                  iconColor: palette.expense,
                  iconBackground: palette.expenseContainer,
                  currency: currency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCurrentMonth() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final MoneyKind kind;
  final Color iconColor;
  final Color iconBackground;
  final String currency;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.amount,
    required this.kind,
    required this.iconColor,
    required this.iconBackground,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: Sizes.iconCircleSmall + 4,
          height: Sizes.iconCircleSmall + 4,
          decoration: BoxDecoration(
            color: iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: Space.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              MoneyText(
                amount,
                currency: currency,
                kind: kind,
                style: text.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
