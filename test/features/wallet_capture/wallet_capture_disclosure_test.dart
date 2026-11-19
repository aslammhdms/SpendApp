import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/wallet_capture/screens/wallet_capture_screen.dart';

void main() {
  Future<bool?> answer(WidgetTester tester, String button) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showWalletCaptureDisclosure(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Read Google Wallet notifications?'), findsOneWidget);
    expect(find.textContaining('only looks at notifications from Google Wallet'),
        findsOneWidget);

    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('agreeing returns true', (tester) async {
    expect(await answer(tester, 'Agree'), isTrue);
  });

  testWidgets('declining returns false', (tester) async {
    expect(await answer(tester, 'Not now'), isFalse);
  });
}
