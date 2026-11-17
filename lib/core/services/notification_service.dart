import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../theme/app_color_schemes.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Shows the app's local notifications. The rest of the app goes through
/// this class rather than the plugin, so tests can swap it out.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;

  /// The status-bar icon (`res/drawable/ic_stat_spendsheet.xml`). Android
  /// draws a notification's small icon as a one-color silhouette, so the
  /// launcher icon would show as a blank square.
  static const _smallIcon = 'ic_stat_spendsheet';

  static const _budgetDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      AppConstants.budgetNotificationChannel,
      'Budget alerts',
      channelDescription: 'Alerts when spending nears or passes a budget',
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      // Tints the icon in the notification shade.
      color: AppColorSchemes.seed,
    ),
    linux: LinuxNotificationDetails(),
  );

  Future<void> _ensureInitialized() {
    return _initialized ??= _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      ),
    );
  }

  /// Asks for permission to show notifications where the system requires
  /// it (Android 13 and later). Returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Shows a budget alert. A later alert with the same [id] replaces it.
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _budgetDetails,
    );
  }
}
