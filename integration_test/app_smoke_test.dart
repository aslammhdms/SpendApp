import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_app.dart';

void main() {
  patrolTest('app launches without crash', ($) async {
    await pumpApp($);

    // The app should render something — either splash or a navigated screen
    expect($(Scaffold), findsWidgets);
  });

  patrolTest('splash screen shows SpendSheet branding', ($) async {
    await pumpApp($);

    // Splash is the initial route so it should be visible immediately
    expect($('SpendSheet'), findsOneWidget);
    expect($('Track your expenses effortlessly'), findsOneWidget);
    expect($(CircularProgressIndicator), findsOneWidget);
  });

  patrolTest('splash screen has wallet icon', ($) async {
    await pumpApp($);

    expect($(Icons.account_balance_wallet), findsOneWidget);
  });

  patrolTest('splash navigates away after delay', ($) async {
    await pumpApp($);

    // Splash should be visible initially
    expect($('SpendSheet'), findsOneWidget);

    // Wait for splash to navigate (2s delay + auth init timeout)
    await $.pump(const Duration(seconds: 4));
    await $.pumpAndSettle();

    // After the delay, we should no longer be on the splash screen.
    // We land on either /welcome or /home depending on auth state.
    final hasWelcome = $('Track Expenses').exists || $('Skip').exists;
    final hasHome = $(NavigationBar).exists;
    expect(hasWelcome || hasHome, isTrue,
        reason: 'Should navigate away from splash to welcome or home');
  });
}
