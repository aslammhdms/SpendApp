import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

@freezed
class AppSettings with _$AppSettings {
  const AppSettings._();

  const factory AppSettings({
    @Default('USD') String currency,
    @Default('system') String themeMode,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool budgetAlertsEnabled,
    @Default(false) bool biometricLockEnabled,
    String? spreadsheetId,
    String? spreadsheetUrl,
    DateTime? lastSyncAt,
    @Default(1) int firstDayOfWeek,
    @Default(1) int firstDayOfMonth,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  bool get isConnectedToSheet => spreadsheetId != null;

  Map<String, String> toKeyValueMap() {
    return {
      'currency': currency,
      'theme_mode': themeMode,
      'notifications_enabled': notificationsEnabled ? '1' : '0',
      'budget_alerts_enabled': budgetAlertsEnabled ? '1' : '0',
      'biometric_lock_enabled': biometricLockEnabled ? '1' : '0',
      'spreadsheet_id': spreadsheetId ?? '',
      'spreadsheet_url': spreadsheetUrl ?? '',
      'last_sync_at': lastSyncAt?.toIso8601String() ?? '',
      'first_day_of_week': firstDayOfWeek.toString(),
      'first_day_of_month': firstDayOfMonth.toString(),
    };
  }

  static AppSettings fromKeyValueMap(Map<String, String> map) {
    return AppSettings(
      currency: map['currency'] ?? 'USD',
      themeMode: map['theme_mode'] ?? 'system',
      notificationsEnabled: map['notifications_enabled'] == '1',
      budgetAlertsEnabled: map['budget_alerts_enabled'] == '1',
      biometricLockEnabled: map['biometric_lock_enabled'] == '1',
      spreadsheetId: map['spreadsheet_id']?.isNotEmpty == true
          ? map['spreadsheet_id']
          : null,
      spreadsheetUrl: map['spreadsheet_url']?.isNotEmpty == true
          ? map['spreadsheet_url']
          : null,
      lastSyncAt: map['last_sync_at']?.isNotEmpty == true
          ? DateTime.parse(map['last_sync_at']!)
          : null,
      firstDayOfWeek: int.tryParse(map['first_day_of_week'] ?? '1') ?? 1,
      firstDayOfMonth: int.tryParse(map['first_day_of_month'] ?? '1') ?? 1,
    );
  }
}

@freezed
class SyncQueueItem with _$SyncQueueItem {
  const SyncQueueItem._();

  const factory SyncQueueItem({
    required int id,
    required String entityType,
    required String entityId,
    required String operation,
    required String data,
    required DateTime createdAt,
    @Default(0) int retryCount,
    String? errorMessage,
  }) = _SyncQueueItem;

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) =>
      _$SyncQueueItemFromJson(json);

  bool get isCreate => operation == 'create';
  bool get isUpdate => operation == 'update';
  bool get isDelete => operation == 'delete';
}
