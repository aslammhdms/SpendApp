import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/home/widgets/monthly_summary_card.dart';
import 'package:spendsheet/features/transactions/widgets/transaction_tile.dart';
import 'package:spendsheet/data/models/transaction.dart';

void main() {
  group('Currency propagation', () {
    testWidgets('MonthlySummaryCard shows EUR symbol when currency is EUR',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthlySummaryCard(
              income: 1000.0,
              expense: 500.0,
              balance: 500.0,
              currency: 'EUR',
            ),
          ),
        ),
      );

      // EUR symbol should be present somewhere in the rendered text
      expect(find.textContaining('\u20AC'), findsWidgets);
    });

    testWidgets('MonthlySummaryCard defaults to USD when no currency passed',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthlySummaryCard(
              income: 1000.0,
              expense: 500.0,
              balance: 500.0,
            ),
          ),
        ),
      );

      // USD symbol (\$) should be present
      expect(find.textContaining('\$'), findsWidgets);
    });

    testWidgets('TransactionTile shows GBP symbol when currency is GBP',
        (tester) async {
      final transaction = Transaction(
        id: 'test-1',
        date: DateTime(2024, 6, 15),
        amount: 42.50,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        createdAt: DateTime(2024, 6, 15),
        updatedAt: DateTime(2024, 6, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              transaction: transaction,
              currency: 'GBP',
            ),
          ),
        ),
      );

      // GBP symbol (£) should be present
      expect(find.textContaining('\u00A3'), findsOneWidget);
    });

    testWidgets('TransactionTile defaults to USD symbol',
        (tester) async {
      final transaction = Transaction(
        id: 'test-2',
        date: DateTime(2024, 6, 15),
        amount: 25.00,
        type: TransactionType.income,
        categoryId: 'cat-2',
        accountId: 'acc-1',
        createdAt: DateTime(2024, 6, 15),
        updatedAt: DateTime(2024, 6, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              transaction: transaction,
            ),
          ),
        ),
      );

      // USD symbol (\$) should be present
      expect(find.textContaining('\$'), findsOneWidget);
    });
  });
}
