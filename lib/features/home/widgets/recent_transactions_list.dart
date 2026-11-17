import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onViewAll;
  final Function(Transaction)? onTap;
  final String currency;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    this.onViewAll,
    this.onTap,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Recent Transactions',
            actionLabel: 'View All',
            onAction: onViewAll,
          ),
          if (transactions.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              compact: true,
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Column(
                children: [
                  for (final transaction in transactions)
                    _TransactionItem(
                      transaction: transaction,
                      currency: currency,
                      onTap: onTap != null ? () => onTap!(transaction) : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final String currency;
  final VoidCallback? onTap;

  const _TransactionItem({
    required this.transaction,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final (MoneyKind kind, String prefix, IconData icon, Color fg) = isExpense
        ? (
            MoneyKind.expense,
            '-',
            Icons.north_east_rounded,
            palette.expense,
          )
        : isIncome
            ? (
                MoneyKind.income,
                '+',
                Icons.south_west_rounded,
                palette.income,
              )
            : (
                MoneyKind.transfer,
                '',
                Icons.swap_horiz_rounded,
                palette.transfer,
              );

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xl,
            vertical: Space.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: Sizes.iconCircle,
                height: Sizes.iconCircle,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: fg, size: Sizes.icon),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.note?.isNotEmpty == true
                          ? transaction.note!
                          : (isTransfer ? 'Transfer' : 'Transaction'),
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.getRelativeDate(transaction.date),
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              MoneyText(
                transaction.amount,
                currency: currency,
                kind: kind,
                prefix: prefix,
                style: text.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
