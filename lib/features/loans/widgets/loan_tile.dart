import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/loan.dart';

class LoanTile extends StatelessWidget {
  final Loan loan;
  final String currency;

  const LoanTile({
    super.key,
    required this.loan,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String title;

    if (loan.isSettlement) {
      icon = Icons.check_circle_outline;
      iconColor = AppColors.primary;
      title = 'Settlement';
    } else if (loan.isLent) {
      icon = Icons.arrow_upward;
      iconColor = AppColors.income;
      title = 'Lent';
    } else {
      icon = Icons.arrow_downward;
      iconColor = AppColors.expense;
      title = 'Borrowed';
    }

    final formattedAmount =
        CurrencyUtils.format(loan.amount, currencyCode: currency);
    final formattedDate = DateFormat.yMMMd().format(loan.date);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        '$title $formattedAmount',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        loan.note != null ? '$formattedDate - ${loan.note}' : formattedDate,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
      ),
    );
  }
}
