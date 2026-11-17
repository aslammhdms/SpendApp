import 'package:flutter/material.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_stat.dart';

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
                      child: SignalStat(
                        label: 'Owed to you',
                        amount: totalOwedToYou,
                        kind: MoneyKind.income,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: SignalStat(
                        label: 'You owe',
                        amount: totalYouOwe,
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
    );
  }
}
