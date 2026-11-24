import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';
import '../../goals/providers/goals_provider.dart';
import '../../goals/screens/goals_screen.dart';
import '../../goals/widgets/goal_card.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../../recurring/screens/recurring_screen.dart' show shortDate;
import '../../transactions/providers/transactions_provider.dart';

/// The next few repeating payments. Hidden until there is one.
class UpcomingPaymentsCard extends ConsumerWidget {
  const UpcomingPaymentsCard({super.key, required this.currency});

  final String currency;

  static const int _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = (ref.watch(recurringRulesProvider).valueOrNull ?? const [])
        .where((r) => r.isActive)
        .take(_shown)
        .toList();
    if (rules.isEmpty) return const SizedBox.shrink();
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Category? categoryOf(String id) {
      for (final c in categories) {
        if (c.id == id) return c;
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              'Upcoming payments',
              actionLabel: 'View All',
              onAction: () => context.push('/recurring'),
            ),
            for (final rule in rules)
              ListTile(
                onTap: () => context.push('/recurring'),
                leading: CategoryIcon(
                  emoji: categoryOf(rule.categoryId)?.icon ?? '🔁',
                  color: Color(categoryOf(rule.categoryId)?.color ??
                      scheme.primary.toARGB32()),
                ),
                title: Text(rule.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  shortDate(rule.nextDueDate),
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                trailing: MoneyText(
                  rule.amount,
                  currency: currency,
                  kind: rule.type == TransactionType.income
                      ? MoneyKind.income
                      : MoneyKind.expense,
                  prefix: rule.type == TransactionType.income ? '+' : '−',
                  style: text.titleSmall,
                ),
              ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
  }
}

/// Savings goals, or an invitation to start one.
class GoalsSummaryCard extends ConsumerWidget {
  const GoalsSummaryCard({super.key, required this.currency});

  final String currency;

  static const int _shown = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    if (!goalsAsync.hasValue) return const SizedBox.shrink();
    final goals = goalsAsync.value!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: goals.isEmpty
            ? ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.lg, vertical: Space.xs),
                leading: Icon(Icons.savings_outlined, color: scheme.primary),
                title: const Text('Start a savings goal'),
                subtitle: const Text('Save towards a phone, a trip, anything'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/goals/add'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    'Savings goals',
                    actionLabel: 'View All',
                    onAction: () => context.push('/goals'),
                  ),
                  for (final goal in goals.take(_shown))
                    GoalCard(
                      goal: goal,
                      currency: currency,
                      compact: true,
                      onTap: () => showGoalActions(context, ref, goal),
                    ),
                ],
              ),
      ),
    );
  }
}
