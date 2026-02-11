import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';

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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return _TransactionItem(
                  transaction: transaction,
                  currency: currency,
                  onTap: onTap != null ? () => onTap!(transaction) : null,
                );
              },
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
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    Color amountColor;
    String prefix;

    if (isExpense) {
      amountColor = AppColors.expense;
      prefix = '-';
    } else if (isIncome) {
      amountColor = AppColors.income;
      prefix = '+';
    } else {
      amountColor = AppColors.transfer;
      prefix = '';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: amountColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isTransfer
                    ? Icons.swap_horiz
                    : (isExpense ? Icons.arrow_upward : Icons.arrow_downward),
                color: amountColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note?.isNotEmpty == true
                        ? transaction.note!
                        : (isTransfer ? 'Transfer' : 'Transaction'),
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppDateUtils.getRelativeDate(transaction.date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$prefix${CurrencyUtils.format(transaction.amount, currencyCode: currency)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
