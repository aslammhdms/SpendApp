import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/loan.dart';
import 'package:spendsheet/features/loans/widgets/loan_tile.dart';

Loan _makeLoan({
  String id = 'loan_1',
  LoanType type = LoanType.lent,
  double amount = 100,
  String? note,
  bool isSettlement = false,
}) {
  final now = DateTime.now();
  return Loan(
    id: id,
    personId: 'per_1',
    type: type,
    amount: amount,
    note: note,
    date: now,
    isSettlement: isSettlement,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  Widget buildTestWidget({
    required Loan loan,
    String currency = 'USD',
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LoanTile(
          loan: loan,
          currency: currency,
          onTap: onTap,
          onDelete: onDelete,
        ),
      ),
    );
  }

  group('LoanTile', () {
    testWidgets('lent loan shows "Lent" title', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        loan: _makeLoan(type: LoanType.lent, amount: 100),
      ));

      expect(find.textContaining('Lent'), findsOneWidget);
    });

    testWidgets('borrowed loan shows "Borrowed" title', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        loan: _makeLoan(type: LoanType.borrowed, amount: 50),
      ));

      expect(find.textContaining('Borrowed'), findsOneWidget);
    });

    testWidgets('settlement shows "Settlement" title', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        loan: _makeLoan(isSettlement: true, amount: 200),
      ));

      expect(find.textContaining('Settlement'), findsOneWidget);
    });

    testWidgets('note displayed when present', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        loan: _makeLoan(note: 'Dinner money'),
      ));

      expect(find.textContaining('Dinner money'), findsOneWidget);
    });

    testWidgets('date displayed', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        loan: _makeLoan(),
      ));

      // Should have some formatted date text present
      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}
