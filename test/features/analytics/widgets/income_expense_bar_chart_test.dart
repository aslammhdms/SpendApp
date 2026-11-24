import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/analytics/widgets/income_expense_bar_chart.dart';

void main() {
  group('IncomeExpenseBarChart', () {
    testWidgets('renders "No data for this period" when both maps empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IncomeExpenseBarChart(
              monthlyExpenses: {},
              monthlyIncome: {},
            ),
          ),
        ),
      );

      expect(find.text('No data for this period'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('renders chart WITHOUT CRASH when all values are 0',
        (tester) async {
      final expenses = {
        DateTime(2024, 1): 0.0,
        DateTime(2024, 2): 0.0,
      };
      final income = {
        DateTime(2024, 1): 0.0,
        DateTime(2024, 2): 0.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeExpenseBarChart(
              monthlyExpenses: expenses,
              monthlyIncome: income,
            ),
          ),
        ),
      );

      // Should not crash — should render chart title
      expect(find.text('Income vs Expense'), findsOneWidget);
      expect(find.text('No data for this period'), findsNothing);
    });

    testWidgets('renders chart with normal data', (tester) async {
      final expenses = {
        DateTime(2024, 1): 500.0,
        DateTime(2024, 2): 750.0,
        DateTime(2024, 3): 600.0,
      };
      final income = {
        DateTime(2024, 1): 3000.0,
        DateTime(2024, 2): 3000.0,
        DateTime(2024, 3): 3200.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeExpenseBarChart(
              monthlyExpenses: expenses,
              monthlyIncome: income,
            ),
          ),
        ),
      );

      expect(find.text('Income vs Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
    });

    testWidgets('renders with only income data (no expenses)', (tester) async {
      final expenses = <DateTime, double>{};
      final income = {
        DateTime(2024, 1): 3000.0,
        DateTime(2024, 2): 3500.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeExpenseBarChart(
              monthlyExpenses: expenses,
              monthlyIncome: income,
            ),
          ),
        ),
      );

      // monthlyExpenses is empty but monthlyIncome is not, so chart should render
      // The widget checks: if (monthlyExpenses.isEmpty && monthlyIncome.isEmpty)
      // Since only one is empty, chart should render
      expect(find.text('Income vs Expense'), findsOneWidget);
    });

    testWidgets('renders with only expense data (no income)', (tester) async {
      final expenses = {
        DateTime(2024, 1): 500.0,
        DateTime(2024, 2): 750.0,
      };
      final income = <DateTime, double>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeExpenseBarChart(
              monthlyExpenses: expenses,
              monthlyIncome: income,
            ),
          ),
        ),
      );

      expect(find.text('Income vs Expense'), findsOneWidget);
    });
  });
}
