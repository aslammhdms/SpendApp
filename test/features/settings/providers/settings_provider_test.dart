import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/app_settings.dart';
import 'package:spendsheet/data/repositories/settings_repository.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';
import 'package:spendsheet/features/settings/providers/settings_provider.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late MockSettingsRepository mockRepo;
  late MockSyncEngine mockSyncEngine;
  late SettingsNotifier notifier;

  setUp(() {
    mockRepo = MockSettingsRepository();
    mockSyncEngine = MockSyncEngine();
    notifier = SettingsNotifier(mockRepo, mockSyncEngine);
  });

  group('SettingsNotifier', () {
    test('initial state has defaults', () {
      expect(notifier.state.currency, 'USD');
      expect(notifier.state.themeMode, 'system');
      expect(notifier.state.notificationsEnabled, isTrue);
      expect(notifier.state.budgetAlertsEnabled, isTrue);
      expect(notifier.state.biometricLockEnabled, isFalse);
    });

    test('loadSettings reads from repository', () async {
      final settings = const AppSettings(
        currency: 'EUR',
        themeMode: 'dark',
        notificationsEnabled: false,
      );
      when(() => mockRepo.getSettings())
          .thenAnswer((_) async => settings);

      await notifier.loadSettings();

      expect(notifier.state.currency, 'EUR');
      expect(notifier.state.themeMode, 'dark');
      expect(notifier.state.notificationsEnabled, isFalse);
    });

    test('setCurrency persists and updates state', () async {
      when(() => mockRepo.setCurrency(any()))
          .thenAnswer((_) async {});

      await notifier.setCurrency('GBP');

      expect(notifier.state.currency, 'GBP');
      verify(() => mockRepo.setCurrency('GBP')).called(1);
    });

    test('setThemeMode persists and updates state', () async {
      when(() => mockRepo.setThemeMode(any()))
          .thenAnswer((_) async {});

      await notifier.setThemeMode('dark');

      expect(notifier.state.themeMode, 'dark');
      verify(() => mockRepo.setThemeMode('dark')).called(1);
    });

    test('setNotificationsEnabled persists and updates state', () async {
      when(() => mockRepo.setNotificationsEnabled(any()))
          .thenAnswer((_) async {});

      await notifier.setNotificationsEnabled(false);

      expect(notifier.state.notificationsEnabled, isFalse);
    });

    test('setBudgetAlertsEnabled persists and updates state', () async {
      when(() => mockRepo.setBudgetAlertsEnabled(any()))
          .thenAnswer((_) async {});

      await notifier.setBudgetAlertsEnabled(false);

      expect(notifier.state.budgetAlertsEnabled, isFalse);
    });

    test('setBiometricLockEnabled persists and updates state', () async {
      when(() => mockRepo.setBiometricLockEnabled(any()))
          .thenAnswer((_) async {});

      await notifier.setBiometricLockEnabled(true);

      expect(notifier.state.biometricLockEnabled, isTrue);
    });

    test('clearAllData resets to defaults', () async {
      when(() => mockRepo.clearAll())
          .thenAnswer((_) async {});

      // Set some non-default values first
      when(() => mockRepo.setCurrency(any()))
          .thenAnswer((_) async {});
      await notifier.setCurrency('EUR');

      await notifier.clearAllData();

      expect(notifier.state.currency, 'USD');
      expect(notifier.state.themeMode, 'system');
      verify(() => mockRepo.clearAll()).called(1);
    });
  });
}
