import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  static const String _keyPrefix = 'settings_';

  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      currency: prefs.getString('${_keyPrefix}currency') ?? 'USD',
      themeMode: prefs.getString('${_keyPrefix}theme_mode') ?? 'system',
      notificationsEnabled: prefs.getBool('${_keyPrefix}notifications_enabled') ?? true,
      budgetAlertsEnabled: prefs.getBool('${_keyPrefix}budget_alerts_enabled') ?? true,
      biometricLockEnabled: prefs.getBool('${_keyPrefix}biometric_lock_enabled') ?? false,
      spreadsheetId: prefs.getString('${_keyPrefix}spreadsheet_id'),
      spreadsheetUrl: prefs.getString('${_keyPrefix}spreadsheet_url'),
      lastSyncAt: prefs.getString('${_keyPrefix}last_sync_at') != null
          ? DateTime.parse(prefs.getString('${_keyPrefix}last_sync_at')!)
          : null,
      firstDayOfWeek: prefs.getInt('${_keyPrefix}first_day_of_week') ?? 1,
      firstDayOfMonth: prefs.getInt('${_keyPrefix}first_day_of_month') ?? 1,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('${_keyPrefix}currency', settings.currency);
    await prefs.setString('${_keyPrefix}theme_mode', settings.themeMode);
    await prefs.setBool('${_keyPrefix}notifications_enabled', settings.notificationsEnabled);
    await prefs.setBool('${_keyPrefix}budget_alerts_enabled', settings.budgetAlertsEnabled);
    await prefs.setBool('${_keyPrefix}biometric_lock_enabled', settings.biometricLockEnabled);

    if (settings.spreadsheetId != null) {
      await prefs.setString('${_keyPrefix}spreadsheet_id', settings.spreadsheetId!);
    }
    if (settings.spreadsheetUrl != null) {
      await prefs.setString('${_keyPrefix}spreadsheet_url', settings.spreadsheetUrl!);
    }
    if (settings.lastSyncAt != null) {
      await prefs.setString('${_keyPrefix}last_sync_at', settings.lastSyncAt!.toIso8601String());
    }

    await prefs.setInt('${_keyPrefix}first_day_of_week', settings.firstDayOfWeek);
    await prefs.setInt('${_keyPrefix}first_day_of_month', settings.firstDayOfMonth);
  }

  Future<void> setCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyPrefix}currency', currency);
  }

  Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyPrefix}currency') ?? 'USD';
  }

  Future<void> setThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyPrefix}theme_mode', themeMode);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyPrefix}theme_mode') ?? 'system';
  }

  Future<void> setSpreadsheetId(String spreadsheetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyPrefix}spreadsheet_id', spreadsheetId);
  }

  Future<String?> getSpreadsheetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyPrefix}spreadsheet_id');
  }

  Future<void> setSpreadsheetUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyPrefix}spreadsheet_url', url);
  }

  Future<String?> getSpreadsheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyPrefix}spreadsheet_url');
  }

  Future<void> setLastSyncAt(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyPrefix}last_sync_at', dateTime.toIso8601String());
  }

  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString('${_keyPrefix}last_sync_at');
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_keyPrefix}notifications_enabled', enabled);
  }

  Future<void> setBudgetAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_keyPrefix}budget_alerts_enabled', enabled);
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_keyPrefix}biometric_lock_enabled', enabled);
  }

  Future<bool> isOnboarded() async {
    final spreadsheetId = await getSpreadsheetId();
    return spreadsheetId != null && spreadsheetId.isNotEmpty;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
