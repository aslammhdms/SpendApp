import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/signal_stat.dart';

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
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final isSaving = balance >= 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.xxlAll,
        boxShadow: [
          BoxShadow(
            color: palette.heroShadow,
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: Radii.xxlAll,
        child: ColoredBox(
          // One flat color: no gradient, no highlights.
          color: palette.hero,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        Space.lg,
                        Space.lg,
                        Space.xl - Space.xs,
                      ),
                      child: _buildHeadline(context, palette, text, isSaving),
                    ),
                    // Income and expense sit on a solid panel, so the
                    // green and red signals keep their contrast.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                        vertical: Space.md + 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.raisedSurface,
                        borderRadius: Radii.xlAll,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SignalStat(
                              label: 'Income',
                              amount: income,
                              kind: MoneyKind.income,
                              currency: currency,
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: SignalStat(
                              label: 'Expense',
                              amount: expense,
                              kind: MoneyKind.expense,
                              currency: currency,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline(
    BuildContext context,
    AppPalette palette,
    TextTheme text,
    bool isSaving,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'This Month',
                style: text.titleSmall?.copyWith(color: palette.onHeroMuted),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm + 2,
                vertical: Space.xs,
              ),
              decoration: BoxDecoration(
                color: palette.heroShade,
                borderRadius: Radii.smAll,
                border: Border.all(color: palette.heroGlow),
              ),
              child: Text(
                _getCurrentMonth(),
                style: text.labelMedium?.copyWith(color: palette.onHero),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AnimatedMoney(
          balance,
          currency: currency,
          semanticLabel: isSaving ? 'Net savings' : 'Over budget',
          style: text.displayMedium?.copyWith(color: palette.onHero),
        ),
        const SizedBox(height: Space.xs),
        if (isSaving)
          Text(
            'Net savings',
            style: text.bodyMedium?.copyWith(color: palette.onHeroMuted),
          )
        else
          // Red would not be readable on the gradient, so the warning is
          // a solid red-tinted badge.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs / 2,
            ),
            decoration: BoxDecoration(
              color: palette.expenseContainer,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              'Over budget',
              style: text.labelLarge
                  ?.copyWith(color: palette.onExpenseContainer),
            ),
          ),
      ],
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
