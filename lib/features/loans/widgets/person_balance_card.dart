import 'package:material_ui/material_ui.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/person.dart';
import '../../../shared/widgets/money_text.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final balance = person.netBalance;
    final (String subtitle, MoneyKind kind) = balance > 0
        ? ('owes you', MoneyKind.income)
        : balance < 0
            ? ('you owe', MoneyKind.expense)
            : ('settled', MoneyKind.neutral);

    return Slidable(
      endActionPane: onDelete != null
          ? ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => onDelete!(),
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  borderRadius: Radii.lgAll,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                ),
              ],
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md + 2,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: Sizes.iconCircle / 2,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: text.titleMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name, style: text.titleSmall),
                      Text(
                        subtitle,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                MoneyText(
                  balance.abs(),
                  currency: currency,
                  kind: kind,
                  semanticLabel: '${person.name} $subtitle',
                  color: kind == MoneyKind.neutral
                      ? scheme.onSurfaceVariant
                      : null,
                  style: text.titleMedium,
                ),
                const SizedBox(width: Space.xs),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
