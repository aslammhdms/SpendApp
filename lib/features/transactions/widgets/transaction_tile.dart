import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/money_text.dart';

/// One transaction in a list: category icon, name, note and time, amount.
///
/// In lists, expenses are shown in the neutral text color with a minus
/// sign and income in green, so a long list doesn't turn red; screen
/// readers still hear "Expense" or "Income".
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
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final (
      MoneyKind kind,
      String prefix,
      IconData icon,
      Color amountColor
    ) = isExpense
        ? (MoneyKind.expense, '-', Icons.north_east_rounded, scheme.onSurface)
        : isIncome
            ? (MoneyKind.income, '+', Icons.south_west_rounded, palette.income)
            : (
                MoneyKind.transfer,
                '',
                Icons.swap_horiz_rounded,
                palette.transfer
              );

    final secondary = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit!(),
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              icon: Icons.edit_outlined,
              label: 'Edit',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete!(),
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              icon: Icons.delete_outline,
              label: 'Delete',
            ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.sm + 2,
            ),
            child: Row(
              children: [
                category != null
                    ? CategoryIcon(
                        emoji: category!.icon,
                        color: Color(category!.color),
                      )
                    : Container(
                        width: Sizes.iconCircle,
                        height: Sizes.iconCircle,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: amountColor, size: Sizes.icon),
                      ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ??
                            (isTransfer ? 'Transfer' : 'Transaction'),
                        style: text.titleSmall,
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
                                style: secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(' • ', style: secondary),
                          ],
                          if (transaction.recurringId != null) ...[
                            Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: secondary?.color,
                              semanticLabel: 'Repeating',
                            ),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            AppDateUtils.formatDisplayTime(transaction.date),
                            style: secondary,
                          ),
                          if (transaction.labels.isNotEmpty) ...[
                            Text(' • ', style: secondary),
                            Flexible(
                              child: Text(
                                transaction.labels.join(', '),
                                style: secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      transaction.amount,
                      currency: currency,
                      kind: kind,
                      prefix: prefix,
                      color: amountColor,
                      style: text.titleSmall,
                    ),
                    if (transaction.receiptUrl != null) ...[
                      const SizedBox(height: 2),
                      Icon(
                        Icons.receipt_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                        semanticLabel: 'Has receipt',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
