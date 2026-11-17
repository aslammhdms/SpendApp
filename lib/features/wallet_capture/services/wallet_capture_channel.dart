import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A notification as the Android listener handed it over.
class RawWalletNotification {
  const RawWalletNotification({
    required this.key,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  final String key;
  final String title;
  final String text;
  final DateTime postedAt;
}

/// Bridge to the Android notification listener (WalletNotificationListener).
///
/// Capture only exists on Android; everywhere else [isSupported] is false
/// and the other calls do nothing.
class WalletCaptureChannel {
  const WalletCaptureChannel();

  static const _channel = MethodChannel('spendsheet/wallet_capture');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the user has given SpendSheet notification access in Android
  /// settings.
  Future<bool> hasAccess() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasAccess') ?? false;
  }

  /// Opens Android's "Notification access" settings page.
  Future<void> openAccessSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openAccessSettings');
  }

  /// Tells the listener whether to keep Google Wallet notifications.
  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('setEnabled', enabled);
  }

  /// Collects the notifications captured since the last call.
  Future<List<RawWalletNotification>> drain() async {
    if (!isSupported) return const [];
    final items = await _channel.invokeListMethod<Map<Object?, Object?>>('drain');
    return [
      for (final item in items ?? const <Map<Object?, Object?>>[])
        RawWalletNotification(
          key: item['key'] as String? ?? '',
          title: item['title'] as String? ?? '',
          text: item['text'] as String? ?? '',
          postedAt: DateTime.fromMillisecondsSinceEpoch(
            (item['postedAt'] as num?)?.toInt() ?? 0,
          ),
        ),
    ];
  }
}
