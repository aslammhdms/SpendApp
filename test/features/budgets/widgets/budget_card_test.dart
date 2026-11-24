import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/features/budgets/widgets/budget_card.dart';

Budget _makeBudget({
  String id = 'bud_1',
  String name = 'Food Budget',
  double amount = 500,
  double spentAmount = 0,
  BudgetPeriod period = BudgetPeriod.monthly,
  String? categoryId = 'cat_food',
}) {
  final now = DateTime.now();
  return Budget(
    id: id,
    name: name,
    amount: amount,
    period: period,
    categoryId: categoryId,
    startDate: now,
    createdAt: now,
    updatedAt: now,
    spentAmount: spentAmount,
  );
}

void main() {
  Widget buildTestWidget({
    required Budget budget,
    String? categoryIcon,
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    String currency = 'USD',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BudgetCard(
          budget: budget,
          categoryIcon: categoryIcon,
          onTap: onTap,
          onEdit: onEdit,
          onDelete: onDelete,
          currency: currency,
        ),
      ),
    );
  }

  group('BudgetCard', () {
    testWidgets('renders name and period label', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(name: 'Groceries', period: BudgetPeriod.weekly),
      ));

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Weekly budget'), findsOneWidget);
    });

    testWidgets('monthly period shows Monthly budget', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(period: BudgetPeriod.monthly),
      ));

      expect(find.text('Monthly budget'), findsOneWidget);
    });

    testWidgets('yearly period shows Yearly budget', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(period: BudgetPeriod.yearly),
      ));

      expect(find.text('Yearly budget'), findsOneWidget);
    });

    testWidgets('shows "X left" when under budget', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(amount: 500, spentAmount: 200),
      ));

      expect(find.textContaining('left'), findsOneWidget);
    });

    testWidgets('shows "X over" when over budget', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(amount: 100, spentAmount: 150),
      ));

      expect(find.textContaining('over'), findsOneWidget);
    });

    testWidgets('percentage displayed correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(amount: 200, spentAmount: 100),
      ));

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('category icon shown when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(),
        categoryIcon: '🍔',
      ));

      // The stored emoji is shown as its matching Material icon.
      expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    });

    testWidgets('unmapped category emoji is shown as is', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(),
        categoryIcon: '🦄',
      ));

      expect(find.text('🦄'), findsOneWidget);
    });

    testWidgets('popup menu has Edit and Delete options', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budget: _makeBudget(),
        onEdit: () {},
        onDelete: () {},
      ));

      // Open the options menu
      await tester.tap(find.byTooltip('Budget options'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}
