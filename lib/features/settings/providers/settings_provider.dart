import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/remote/sync_engine.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../onboarding/providers/sheet_setup_provider.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;
  final SyncEngine _syncEngine;

  SettingsNotifier(this._repository, this._syncEngine)
      : super(const AppSettings());

  Future<void> loadSettings() async {
    final settings = await _repository.getSettings();
    state = settings;
  }

  Future<void> setCurrency(String currency) async {
    await _repository.setCurrency(currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> setThemeMode(String themeMode) async {
    await _repository.setThemeMode(themeMode);
    state = state.copyWith(themeMode: themeMode);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _repository.setNotificationsEnabled(enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  Future<void> setBudgetAlertsEnabled(bool enabled) async {
    await _repository.setBudgetAlertsEnabled(enabled);
    state = state.copyWith(budgetAlertsEnabled: enabled);
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    await _repository.setBiometricLockEnabled(enabled);
    state = state.copyWith(biometricLockEnabled: enabled);
  }

  Future<void> sync() async {
    await _syncEngine.sync();
    final lastSync = await _syncEngine.getLastSyncTime();
    state = state.copyWith(lastSyncAt: lastSync);
  }

  Future<void> fullSync() async {
    await _syncEngine.fullSync();
    final lastSync = await _syncEngine.getLastSyncTime();
    state = state.copyWith(lastSyncAt: lastSync);
  }

  SyncStatus get syncStatus => _syncEngine.currentStatus;

  Stream<SyncStatus> get syncStatusStream => _syncEngine.statusStream;

  Future<int> getPendingSyncCount() async {
    return await _syncEngine.getPendingCount();
  }

  Future<void> clearAllData() async {
    await _repository.clearAll();
    state = const AppSettings();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return SettingsNotifier(repository, syncEngine);
});
