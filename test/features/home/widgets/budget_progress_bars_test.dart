import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/features/home/widgets/budget_progress_bars.dart';

Budget _makeBudget({
  required String id,
  String name = 'Budget',
  double amount = 500,
  double spentAmount = 0,
  BudgetPeriod period = BudgetPeriod.monthly,
}) {
  final now = DateTime.now();
  return Budget(
    id: id,
    name: name,
    amount: amount,
    period: period,
    startDate: now,
    createdAt: now,
    updatedAt: now,
    spentAmount: spentAmount,
  );
}

void main() {
  Widget buildTestWidget({
    List<Budget> budgets = const [],
    VoidCallback? onViewAll,
    String currency = 'USD',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BudgetProgressBars(
          budgets: budgets,
          onViewAll: onViewAll,
          currency: currency,
        ),
      ),
    );
  }

  group('BudgetProgressBars', () {
    testWidgets('empty budgets shows empty message', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No budgets set'), findsOneWidget);
      expect(find.text('Budget Status'), findsOneWidget);
    });

    testWidgets('shows max 3 budgets', (tester) async {
      final budgets = List.generate(5, (i) =>
          _makeBudget(id: 'bud_$i', name: 'Budget $i', spentAmount: 100));

      await tester.pumpWidget(buildTestWidget(budgets: budgets));

      expect(find.text('Budget 0'), findsOneWidget);
      expect(find.text('Budget 1'), findsOneWidget);
      expect(find.text('Budget 2'), findsOneWidget);
      expect(find.text('Budget 3'), findsNothing);
      expect(find.text('Budget 4'), findsNothing);
    });

    testWidgets('"View All" appears when >3 budgets', (tester) async {
      final budgets = List.generate(4, (i) =>
          _makeBudget(id: 'bud_$i', name: 'Budget $i'));

      bool viewAllTapped = false;
      await tester.pumpWidget(buildTestWidget(
        budgets: budgets,
        onViewAll: () => viewAllTapped = true,
      ));

      expect(find.text('View All'), findsOneWidget);
      await tester.tap(find.text('View All'));
      expect(viewAllTapped, isTrue);
    });

    testWidgets('"View All" hidden when <=3 budgets', (tester) async {
      final budgets = List.generate(2, (i) =>
          _makeBudget(id: 'bud_$i', name: 'Budget $i'));

      await tester.pumpWidget(buildTestWidget(
        budgets: budgets,
        onViewAll: () {},
      ));

      expect(find.text('View All'), findsNothing);
    });

    testWidgets('percentage text shown correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budgets: [_makeBudget(id: 'bud_1', amount: 500, spentAmount: 250)],
      ));

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('over-budget percentage shown correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budgets: [_makeBudget(id: 'bud_1', amount: 100, spentAmount: 120)],
      ));

      expect(find.text('120%'), findsOneWidget);
    });
  });
}
