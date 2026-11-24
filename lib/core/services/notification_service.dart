import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
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
      // Amounts stay off a locked screen that hides sensitive content.
      visibility: NotificationVisibility.private,
      // Tints the icon in the notification shade.
      color: AppColorSchemes.seed,
    ),
    linux: LinuxNotificationDetails(),
  );

  static NotificationDetails _details({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: _smallIcon,
        visibility: NotificationVisibility.private,
        color: AppColorSchemes.seed,
        styleInformation: const BigTextStyleInformation(''),
      ),
      linux: const LinuxNotificationDetails(),
    );
  }

  static final _reminderDetails = _details(
    channelId: AppConstants.reminderNotificationChannel,
    channelName: 'Repeating payments',
    channelDescription: 'A reminder the day before a repeating payment',
  );

  static final _summaryDetails = _details(
    channelId: AppConstants.summaryNotificationChannel,
    channelName: 'Spending summaries',
    channelDescription: 'What you spent last week or last month',
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

  /// Whether the system will display this app's notifications. Android
  /// drops a blocked notification without any error, so callers check this
  /// before treating an alert as shown.
  Future<bool> areEnabled() async {
    try {
      await _ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('Notification status check failed: $e');
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

  /// Shows a reminder about a repeating payment at [when]. A later call with
  /// the same [id] replaces it.
  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) =>
      _schedule(id, when, title, body, _reminderDetails);

  /// Shows a spending summary at [when]. A later call with the same [id]
  /// replaces it.
  Future<void> scheduleSummary({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) =>
      _schedule(id, when, title, body, _summaryDetails);

  Future<void> _schedule(
    int id,
    DateTime when,
    String title,
    String body,
    NotificationDetails details,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: id,
      // The moment itself, held in UTC, so no time zone database is needed.
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: details,
      // Inexact: needs no alarm permission, and a few minutes either way
      // does not matter for a reminder or a summary.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  /// Withdraws a scheduled or shown notification.
  Future<void> cancel(int id) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }
}
