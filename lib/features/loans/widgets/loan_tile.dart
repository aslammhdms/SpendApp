import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/loan.dart';

class LoanTile extends StatelessWidget {
  final Loan loan;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const LoanTile({
    super.key,
    required this.loan,
    this.currency = 'USD',
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (IconData icon, Color iconColor, String title) = loan.isSettlement
        ? (Icons.check_circle_outline, scheme.primary, 'Settlement')
        : loan.isLent
            ? (Icons.north_east_rounded, palette.income, 'Lent')
            : (Icons.south_west_rounded, palette.expense, 'Borrowed');

    final formattedAmount =
        CurrencyUtils.format(loan.amount, currencyCode: currency);
    final formattedDate = DateFormat.yMMMd().format(loan.date);

    return Slidable(
      endActionPane: onDelete != null
          ? ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => onDelete!(),
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                ),
              ],
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
          leading: Container(
            width: Sizes.iconCircle,
            height: Sizes.iconCircle,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: Sizes.icon),
          ),
          title: Text(
            '$title $formattedAmount',
            style: text.titleSmall?.tabular,
          ),
          subtitle: Text(
            loan.note != null ? '$formattedDate - ${loan.note}' : formattedDate,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
