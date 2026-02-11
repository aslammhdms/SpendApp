import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_app.dart';

void main() {
  /// Helper: wait for splash to finish and land on welcome screen.
  Future<void> waitForWelcome(PatrolIntegrationTester $) async {
    await pumpApp($);
    await $.pump(const Duration(seconds: 4));
    await $.pumpAndSettle();
  }

  patrolTest('welcome screen shows first page "Track Expenses"', ($) async {
    await waitForWelcome($);

    // If we landed on home instead of welcome, skip gracefully.
    if ($(NavigationBar).exists) return;

    expect($('Track Expenses'), findsOneWidget);
    expect(
      $('Easily log your daily expenses and income with just a few taps.'),
      findsOneWidget,
    );
  });

  patrolTest('can tap Next through all 4 pages', ($) async {
    await waitForWelcome($);
    if ($(NavigationBar).exists) return;

    // Page 1: Track Expenses
    expect($('Track Expenses'), findsOneWidget);
    expect($('Next'), findsOneWidget);

    // Go to page 2
    await $('Next').tap();
    await $.pumpAndSettle();
    expect($('Sync with Google Sheets'), findsOneWidget);

    // Go to page 3
    await $('Next').tap();
    await $.pumpAndSettle();
    expect($('Insightful Analytics'), findsOneWidget);

    // Go to page 4
    await $('Next').tap();
    await $.pumpAndSettle();
    expect($('Budget Wisely'), findsOneWidget);
  });

  patrolTest('last page shows "Get Started" and hides "Skip"', ($) async {
    await waitForWelcome($);
    if ($(NavigationBar).exists) return;

    // Navigate to last page
    await $('Next').tap();
    await $.pumpAndSettle();
    await $('Next').tap();
    await $.pumpAndSettle();
    await $('Next').tap();
    await $.pumpAndSettle();

    expect($('Budget Wisely'), findsOneWidget);
    expect($('Get Started'), findsOneWidget);
    expect($('Next'), findsNothing);
    expect($('Skip'), findsNothing);
  });

  patrolTest('Skip button navigates to sign-in screen', ($) async {
    await waitForWelcome($);
    if ($(NavigationBar).exists) return;

    // Skip should be visible on page 1
    expect($('Skip'), findsOneWidget);

    await $('Skip').tap();
    await $.pumpAndSettle();

    // Should land on sign-in screen
    final hasSignIn = $('Sign In').exists ||
        $('Sign in with Google').exists ||
        $('Continue without account').exists;
    expect(hasSignIn, isTrue,
        reason: 'Should navigate to sign-in screen after Skip');
  });

  patrolTest('"Get Started" on last page navigates to sign-in', ($) async {
    await waitForWelcome($);
    if ($(NavigationBar).exists) return;

    // Navigate to last page
    await $('Next').tap();
    await $.pumpAndSettle();
    await $('Next').tap();
    await $.pumpAndSettle();
    await $('Next').tap();
    await $.pumpAndSettle();

    await $('Get Started').tap();
    await $.pumpAndSettle();

    // Should land on sign-in screen
    final hasSignIn = $('Sign In').exists ||
        $('Sign in with Google').exists ||
        $('Continue without account').exists;
    expect(hasSignIn, isTrue,
        reason: 'Should navigate to sign-in screen after Get Started');
  });
}
