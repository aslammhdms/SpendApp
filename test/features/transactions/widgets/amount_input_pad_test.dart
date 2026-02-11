import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/transactions/widgets/amount_input_pad.dart';

void main() {
  group('AmountInputPad', () {
    late double lastAmount;

    /// Mimics how the real AddEditTransactionScreen uses the pad:
    /// inside an Expanded(flex: 2) within a Column.
    Widget buildWidget({double initialAmount = 0, String currency = 'USD'}) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: AmountInputPad(
                  initialAmount: initialAmount,
                  currency: currency,
                  onAmountChanged: (amount) => lastAmount = amount,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Helper to find a keypad key button by its text label
    Finder findKeypadKey(String key) {
      return find.ancestor(
        of: find.text(key),
        matching: find.byType(InkWell),
      );
    }

    void setLargeScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    setUp(() {
      lastAmount = 0;
    });

    testWidgets('all 12 keys render (0-9, dot, backspace)', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      for (final digit in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(find.text(digit), findsOneWidget, reason: 'Key $digit missing');
      }
      expect(find.text('.'), findsOneWidget, reason: 'Decimal key missing');
      expect(
        find.byIcon(Icons.backspace_outlined),
        findsOneWidget,
        reason: 'Backspace key missing',
      );
    });

    testWidgets('tapping keys builds correct amount', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(lastAmount, 123.0);
    });

    testWidgets('decimal point works', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(findKeypadKey('.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();

      expect(lastAmount, 5.99);
    });

    testWidgets('backspace removes last digit', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(lastAmount, 42.0);

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      expect(lastAmount, 4.0);
    });

    testWidgets('custom currency displays correct symbol', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget(currency: 'EUR'));
      await tester.pumpAndSettle();

      // The display should show the EUR symbol
      expect(find.textContaining('\u20AC'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows "Enter amount" hint when empty', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Enter amount'), findsOneWidget);
    });

    testWidgets('hint disappears after entering a digit', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(find.text('Enter amount'), findsNothing);
    });

    testWidgets('only allows one decimal point', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(findKeypadKey('.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      // Try to add a second decimal point — should be ignored
      await tester.tap(findKeypadKey('.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // Second decimal should be ignored, so 1.53
      expect(lastAmount, 1.53);
    });

    testWidgets('limits to 2 decimal places', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(findKeypadKey('.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Third decimal digit should be ignored
      expect(lastAmount, 1.23);
    });
  });
}
