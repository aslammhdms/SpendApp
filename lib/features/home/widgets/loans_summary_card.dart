import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Loans & Debts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton(
                    onPressed: onTap,
                    child: const Text('View All'),
                  ),
                ],
              ),
              if (isEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.handshake_outlined,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No loans yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to add',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                const SizedBox(height: 12),
                _LoanRow(
                  label: 'Owed to you',
                  amount: totalOwedToYou,
                  color: AppColors.income,
                  currency: currency,
                ),
                const SizedBox(height: 8),
                _LoanRow(
                  label: 'You owe',
                  amount: totalYouOwe,
                  color: AppColors.expense,
                  currency: currency,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String currency;

  const _LoanRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          CurrencyUtils.format(amount, currencyCode: currency),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }
}
