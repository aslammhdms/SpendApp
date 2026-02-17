import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/features/home/widgets/recent_transactions_list.dart';

Transaction _makeTransaction({
  required String id,
  double amount = 50,
  TransactionType type = TransactionType.expense,
  String? note,
  DateTime? date,
}) {
  final now = date ?? DateTime.now();
  return Transaction(
    id: id,
    date: now,
    amount: amount,
    type: type,
    categoryId: 'cat_food',
    accountId: 'acc_cash',
    note: note,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  Widget buildTestWidget({
    List<Transaction> transactions = const [],
    VoidCallback? onViewAll,
    Function(Transaction)? onTap,
    String currency = 'USD',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: RecentTransactionsList(
          transactions: transactions,
          onViewAll: onViewAll,
          onTap: onTap,
          currency: currency,
        ),
      ),
    );
  }

  group('RecentTransactionsList', () {
    testWidgets('empty list shows empty state', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
    });

    testWidgets('shows transaction note and relative date', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        transactions: [
          _makeTransaction(id: 'txn_1', note: 'Coffee', amount: 5),
        ],
      ));

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('transfer shows "Transfer" when no note', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        transactions: [
          _makeTransaction(id: 'txn_t', type: TransactionType.transfer),
        ],
      ));

      expect(find.text('Transfer'), findsOneWidget);
    });

    testWidgets('"View All" button triggers callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestWidget(
        transactions: [_makeTransaction(id: 'txn_1')],
        onViewAll: () => tapped = true,
      ));

      await tester.tap(find.text('View All'));
      expect(tapped, isTrue);
    });

    testWidgets('tapping transaction triggers onTap', (tester) async {
      Transaction? tappedTxn;
      final txn = _makeTransaction(id: 'txn_tap', note: 'Tap Me');

      await tester.pumpWidget(buildTestWidget(
        transactions: [txn],
        onTap: (t) => tappedTxn = t,
      ));

      await tester.tap(find.text('Tap Me'));
      expect(tappedTxn, isNotNull);
      expect(tappedTxn!.id, 'txn_tap');
    });
  });
}
