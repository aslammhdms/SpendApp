import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsheet/data/remote/google_auth_service.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';
import 'package:spendsheet/features/auth/providers/auth_provider.dart';
import 'package:spendsheet/features/auth/screens/splash_screen.dart';
import 'package:spendsheet/features/home/providers/dashboard_provider.dart';

import '../../../helpers/mock_sync_engine.dart';

/// Google sign-in stand-in that reports a fixed signed-in state.
class _FakeAuthService extends GoogleAuthService {
  final bool signedIn;

  _FakeAuthService({required this.signedIn});

  @override
  Future<void> init() async {}

  @override
  bool get isSignedIn => signedIn;
}

Widget _splashApp({required bool signedIn, required SyncEngine syncEngine}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/home', builder: (_, __) => const Text('home page')),
    GoRoute(path: '/welcome', builder: (_, __) => const Text('welcome page')),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const Text('onboarding page'),
    ),
  ]);
  return ProviderScope(
    overrides: [
      googleAuthServiceProvider
          .overrideWithValue(_FakeAuthService(signedIn: signedIn)),
      syncEngineProvider.overrideWithValue(syncEngine),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late MockSyncEngine syncEngine;

  setUp(() {
    syncEngine = MockSyncEngine();
    when(() => syncEngine.initialize(any())).thenAnswer((_) async {});
    // Synced recently, so start-up skips the full sync.
    when(() => syncEngine.getLastSyncTime())
        .thenAnswer((_) async => DateTime.now());
  });

  testWidgets('a signed-in user with a connected sheet lands on Home',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings_spreadsheet_id': 'sheet-1',
    });

    await tester.pumpWidget(
      _splashApp(signedIn: true, syncEngine: syncEngine),
    );
    // The splash screen holds for two seconds before routing.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('home page'), findsOneWidget);
    verify(() => syncEngine.initialize('sheet-1')).called(1);
  });

  testWidgets('a signed-in user without a sheet goes to onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      _splashApp(signedIn: true, syncEngine: syncEngine),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('onboarding page'), findsOneWidget);
  });

  testWidgets('a signed-out user goes to Welcome', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      _splashApp(signedIn: false, syncEngine: syncEngine),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('welcome page'), findsOneWidget);
  });
}
