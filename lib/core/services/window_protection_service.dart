import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final windowProtectionServiceProvider = Provider<WindowProtectionService>((ref) {
  return WindowProtectionService();
});

/// Keeps the app's screen out of Android's Recents thumbnails while App Lock
/// is on. Android saves a picture of the last screen when the app leaves the
/// foreground, which the lock screen cannot cover in time.
class WindowProtectionService {
  static const _channel = MethodChannel('spendsheet/app_lock');

  bool? _applied;

  /// Turns the protection on or off. Repeated calls with the same value do
  /// nothing.
  Future<void> setProtected(bool protect) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_applied == protect) return;
    _applied = protect;
    try {
      await _channel.invokeMethod<void>('setProtected', protect);
    } catch (e) {
      _applied = null; // try again next time
      debugPrint('Recents protection change failed: $e');
    }
  }
}
