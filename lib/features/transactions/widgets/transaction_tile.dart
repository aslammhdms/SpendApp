import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String currency;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    Color amountColor;
    String prefix;
    IconData defaultIcon;

    if (isExpense) {
      amountColor = AppColors.expense;
      prefix = '-';
      defaultIcon = Icons.arrow_upward;
    } else if (isIncome) {
      amountColor = AppColors.income;
      prefix = '+';
      defaultIcon = Icons.arrow_downward;
    } else {
      amountColor = AppColors.transfer;
      prefix = '';
      defaultIcon = Icons.swap_horiz;
    }

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit!(),
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete!(),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category != null
                      ? Color(category!.color).withOpacity(0.15)
                      : amountColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: category != null
                      ? Text(
                          category!.icon,
                          style: const TextStyle(fontSize: 20),
                        )
                      : Icon(defaultIcon, color: amountColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ??
                          (isTransfer ? 'Transfer' : 'Transaction'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (transaction.note?.isNotEmpty ?? false) ...[
                          Flexible(
                            child: Text(
                              transaction.note!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ],
                        Text(
                          AppDateUtils.formatDisplayTime(transaction.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${CurrencyUtils.format(transaction.amount, currencyCode: currency)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: amountColor,
                        ),
                  ),
                  if (transaction.receiptUrl != null) ...[
                    const SizedBox(height: 2),
                    Icon(
                      Icons.receipt,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
