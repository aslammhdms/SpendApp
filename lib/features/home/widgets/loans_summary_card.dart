import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';

class LoansSummaryCard extends StatelessWidget {
  final double totalOwedToYou;
  final double totalYouOwe;
  final VoidCallback? onTap;
  final String currency;

  const LoansSummaryCard({
    super.key,
    required this.totalOwedToYou,
    required this.totalYouOwe,
    this.onTap,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isEmpty = totalOwedToYou == 0 && totalYouOwe == 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              'Loans & Debts',
              actionLabel: 'View All',
              onAction: onTap,
            ),
            if (isEmpty)
              const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'No loans yet',
                subtitle: 'Tap to add',
                compact: true,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xl,
                  Space.xs,
                  Space.xl,
                  Space.xl,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _LoanStat(
                        label: 'Owed to you',
                        amount: totalOwedToYou,
                        kind: MoneyKind.income,
                        icon: Icons.south_west_rounded,
                        iconColor: palette.income,
                        iconBackground: palette.incomeContainer,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: _LoanStat(
                        label: 'You owe',
                        amount: totalYouOwe,
                        kind: MoneyKind.expense,
                        icon: Icons.north_east_rounded,
                        iconColor: palette.expense,
                        iconBackground: palette.expenseContainer,
                        currency: currency,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoanStat extends StatelessWidget {
  final String label;
  final double amount;
  final MoneyKind kind;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String currency;

  const _LoanStat({
    required this.label,
    required this.amount,
    required this.kind,
    required this.icon,
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
          decoration:
              BoxDecoration(color: iconBackground, shape: BoxShape.circle),
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
                semanticLabel: label,
                style: text.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
