import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_app.dart';

void main() {
  /// Helper: pump app and wait for splash, then navigate to add transaction.
  /// Returns false if we didn't reach the home screen (unauthenticated).
  Future<bool> navigateToAddTransaction(PatrolIntegrationTester $) async {
    await pumpApp($);
    await $.pump(const Duration(seconds: 4));
    await $.pumpAndSettle();

    if (!$(NavigationBar).exists) return false;

    await $(FloatingActionButton).tap();
    await $.pumpAndSettle();
    return true;
  }

  patrolTest('FAB navigates to add transaction screen', ($) async {
    await pumpApp($);

    await $.pump(const Duration(seconds: 4));
    await $.pumpAndSettle();

    if (!$(NavigationBar).exists) return;

    // Home screen should have a FAB with "Add" label
    expect($(FloatingActionButton), findsOneWidget);
    expect($('Add'), findsOneWidget);

    // Tap the FAB
    await $(FloatingActionButton).tap();
    await $.pumpAndSettle();

    // Should navigate to AddEditTransactionScreen
    expect($('Add Transaction'), findsOneWidget);
  });

  patrolTest('add transaction screen has required form elements', ($) async {
    await pumpApp($);

    await $.pump(const Duration(seconds: 4));
    await $.pumpAndSettle();

    if (!$(NavigationBar).exists) return;

    // Navigate to add transaction
    await $(FloatingActionButton).tap();
    await $.pumpAndSettle();

    // Tab bar with Expense / Income / Transfer
    expect($('Expense'), findsOneWidget);
    expect($('Income'), findsOneWidget);
    expect($('Transfer'), findsOneWidget);

    // Category label should be visible (default tab is Expense)
    expect($('Category'), findsOneWidget);

    // Account label
    expect($('Account'), findsOneWidget);

    // Date picker row
    expect($('Date'), findsOneWidget);

    // Note field
    expect($('Note (optional)'), findsOneWidget);

    // Save button
    expect($('Save'), findsOneWidget);
  });

  patrolTest('all 12 number pad keys are visible (Bug 1 regression)',
      ($) async {
    final reached = await navigateToAddTransaction($);
    if (!reached) return;

    // All digit keys 0-9 should be visible
    for (final digit in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
      expect($(digit), findsWidgets, reason: 'Numpad key $digit not found');
    }

    // Decimal point key
    expect($('.'), findsWidgets, reason: 'Decimal point key not found');

    // Backspace icon
    expect($(Icons.backspace_outlined), findsOneWidget,
        reason: 'Backspace key not found');
  });

  patrolTest('can enter amount using number pad', ($) async {
    final reached = await navigateToAddTransaction($);
    if (!reached) return;

    // Tap some keys to enter an amount
    await $('5').tap();
    await $.pump();
    await $('0').tap();
    await $.pump();
    await $('.').first.tap();
    await $.pump();
    await $('7').tap();
    await $.pump();
    await $('5').tap();
    await $.pump();

    // The amount display should show 50.75 formatted
    expect(find.textContaining('50.75'), findsOneWidget);
  });

  patrolTest('can switch between Expense/Income/Transfer tabs', ($) async {
    final reached = await navigateToAddTransaction($);
    if (!reached) return;

    // Default tab is Expense — should show "Category" and "Account"
    expect($('Category'), findsOneWidget);
    expect($('Account'), findsOneWidget);

    // Switch to Income tab
    await $('Income').tap();
    await $.pumpAndSettle();
    expect($('Category'), findsOneWidget);
    expect($('Account'), findsOneWidget);

    // Switch to Transfer tab — should show "From Account" and "To Account"
    await $('Transfer').tap();
    await $.pumpAndSettle();
    expect($('From Account'), findsOneWidget);
    expect($('To Account'), findsOneWidget);
    // Category should NOT be visible for transfers
    expect($('Category'), findsNothing);
  });
}
