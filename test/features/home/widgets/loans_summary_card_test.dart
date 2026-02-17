import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/home/widgets/loans_summary_card.dart';

void main() {
  Widget buildTestWidget({
    double totalOwedToYou = 0,
    double totalYouOwe = 0,
    VoidCallback? onTap,
    String currency = 'USD',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LoansSummaryCard(
          totalOwedToYou: totalOwedToYou,
          totalYouOwe: totalYouOwe,
          onTap: onTap,
          currency: currency,
        ),
      ),
    );
  }

  group('LoansSummaryCard', () {
    testWidgets('both zero shows empty state', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No loans yet'), findsOneWidget);
      expect(find.text('Loans & Debts'), findsOneWidget);
    });

    testWidgets('shows Owed to you and You owe amounts', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        totalOwedToYou: 500,
        totalYouOwe: 200,
      ));

      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
      expect(find.text('No loans yet'), findsNothing);
    });

    testWidgets('tapping triggers callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestWidget(
        totalOwedToYou: 100,
        totalYouOwe: 0,
        onTap: () => tapped = true,
      ));

      await tester.tap(find.text('View All'));
      expect(tapped, isTrue);
    });

    testWidgets('only one side non-zero still shows both rows',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        totalOwedToYou: 300,
        totalYouOwe: 0,
      ));

      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
    });

    testWidgets('title always shows', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Loans & Debts'), findsOneWidget);
    });
  });
}
