import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/person.dart';

class PersonBalanceCard extends StatelessWidget {
  final Person person;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PersonBalanceCard({
    super.key,
    required this.person,
    this.currency = 'USD',
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final balance = person.netBalance;

    String subtitle;
    Color balanceColor;
    if (balance > 0) {
      subtitle = 'owes you';
      balanceColor = AppColors.income;
    } else if (balance < 0) {
      subtitle = 'you owe';
      balanceColor = AppColors.expense;
    } else {
      subtitle = 'settled';
      balanceColor = AppColors.textTertiary;
    }

    return Slidable(
      endActionPane: onDelete != null
          ? ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => onDelete!(),
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            )
          : null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.format(balance.abs(), currencyCode: currency),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: balanceColor,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
