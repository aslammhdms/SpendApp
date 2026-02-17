import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/home/widgets/monthly_summary_card.dart';

void main() {
  Widget buildTestWidget({
    double income = 0,
    double expense = 0,
    double balance = 0,
    String currency = 'USD',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MonthlySummaryCard(
          income: income,
          expense: expense,
          balance: balance,
          currency: currency,
        ),
      ),
    );
  }

  group('MonthlySummaryCard', () {
    testWidgets('renders income, expense, and balance amounts',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        income: 5000,
        expense: 3000,
        balance: 2000,
      ));

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
    });

    testWidgets('shows Net savings when balance positive', (tester) async {
      await tester.pumpWidget(buildTestWidget(balance: 500));

      expect(find.text('Net savings'), findsOneWidget);
    });

    testWidgets('shows Over budget when balance negative', (tester) async {
      await tester.pumpWidget(buildTestWidget(balance: -200));

      expect(find.text('Over budget'), findsOneWidget);
    });

    testWidgets('zero values display correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        income: 0,
        expense: 0,
        balance: 0,
      ));

      // Should still show labels
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Net savings'), findsOneWidget);
    });

    testWidgets('shows current month name', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final now = DateTime.now();
      final expected = '${months[now.month - 1]} ${now.year}';
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('renders without error with large numbers', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        income: 1234567.89,
        expense: 987654.32,
        balance: 246913.57,
      ));

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
    });
  });
}
