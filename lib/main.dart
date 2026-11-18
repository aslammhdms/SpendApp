import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Read before the first frame, so a locked app never shows its content
  // while the settings are still loading.
  var startLocked = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    startLocked = prefs.getBool(appLockPreferenceKey) ?? false;
  } catch (_) {
    // Unreadable preferences: fall through unlocked, as with no lock set.
  }

  runApp(
    ProviderScope(
      overrides: [startLockedProvider.overrideWithValue(startLocked)],
      child: const SpendSheetApp(),
    ),
  );
}
