import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:spendsheet/app.dart';

/// Pumps the full SpendSheet app wrapped in a ProviderScope.
///
/// All patrol tests should call this instead of manually setting up the app.
Future<void> pumpApp(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const ProviderScope(
      child: SpendSheetApp(),
    ),
  );
}
