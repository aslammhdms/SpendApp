import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsheet/app.dart';
import 'package:spendsheet/core/services/biometric_service.dart';

class _Authenticator extends BiometricService {
  bool allow = false;
  int calls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return allow;
  }
}

const _content = 'LEDGER 123.45';
const _locked = 'SpendSheet is Locked';

Future<_Authenticator> _start(WidgetTester tester, {required bool startLocked}) async {
  SharedPreferences.setMockInitialValues({appLockPreferenceKey: startLocked});
  final authenticator = _Authenticator();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text(_content))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      startLockedProvider.overrideWithValue(startLocked),
      biometricServiceProvider.overrideWithValue(authenticator),
      routerProvider.overrideWithValue(router),
    ],
    child: const SpendSheetApp(),
  ));
  await tester.pump();
  return authenticator;
}

void main() {
  testWidgets('with App Lock on, a fresh start is locked and asks once',
      (tester) async {
    final authenticator = await _start(tester, startLocked: true);

    expect(find.text(_locked), findsOneWidget);
    expect(authenticator.calls, 1);
  });

  testWidgets('a refused prompt keeps it locked; a passed one opens it',
      (tester) async {
    final authenticator = await _start(tester, startLocked: true);

    await tester.tap(find.text('Tap to Unlock'));
    await tester.pump();
    expect(find.text(_locked), findsOneWidget);

    authenticator.allow = true;
    await tester.tap(find.text('Tap to Unlock'));
    await tester.pump();
    expect(find.text(_locked), findsNothing);
    expect(find.text(_content), findsOneWidget);
  });

  testWidgets('with App Lock off, a fresh start is open', (tester) async {
    final authenticator = await _start(tester, startLocked: false);

    expect(find.text(_locked), findsNothing);
    expect(find.text(_content), findsOneWidget);
    expect(authenticator.calls, 0);
  });

  testWidgets('leaving the app covers its content before it is resumed',
      (tester) async {
    final authenticator = await _start(tester, startLocked: true);
    authenticator.allow = true;
    await tester.tap(find.text('Tap to Unlock'));
    await tester.pump();
    expect(find.text(_locked), findsNothing);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    // Android saves the Recents picture here, before the app comes back.
    expect(find.text(_locked), findsOneWidget);
  });

  testWidgets('App Lock keeps the screen out of Recents thumbnails',
      (tester) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('spendsheet/app_lock'),
      (call) async {
        calls.add(call.arguments);
        return null;
      },
    );

    await _start(tester, startLocked: true);

    expect(calls, [true]);
  });
}
