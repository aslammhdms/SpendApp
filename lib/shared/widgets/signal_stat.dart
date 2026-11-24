import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import 'money_text.dart';

/// An income or expense figure with a direction icon in a tinted circle,
/// used on summary cards (Home hero, loans, analytics).
class SignalStat extends StatelessWidget {
  const SignalStat({
    super.key,
    required this.label,
    required this.amount,
    required this.kind,
    this.currency = 'USD',
  });

  final String label;
  final double amount;

  /// [MoneyKind.income] or [MoneyKind.expense]; decides icon and colors.
  final MoneyKind kind;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final isIncome = kind == MoneyKind.income;
    final fg = isIncome ? palette.income : palette.expense;
    final bg = isIncome ? palette.incomeContainer : palette.expenseContainer;

    return Row(
      children: [
        Container(
          width: Sizes.iconCircleSmall + 4,
          height: Sizes.iconCircleSmall + 4,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 18,
            color: fg,
          ),
        ),
        const SizedBox(width: Space.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              MoneyText(
                amount,
                currency: currency,
                kind: kind,
                semanticLabel: label,
                style: text.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
