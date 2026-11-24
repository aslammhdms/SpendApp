import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/sync_status_provider.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../categories/providers/categories_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../loans/providers/loans_provider.dart';
import '../../onboarding/providers/sheet_setup_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/add_edit_transaction_screen.dart'
    show accountsWithBalanceProvider;
import '../../wallet_capture/providers/wallet_capture_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../notices/scheduled_notices_service.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../services/account_data_service.dart';
import '../services/account_session.dart';

final accountDataServiceProvider = Provider<AccountDataService>((ref) {
  return AccountDataService();
});

final accountSessionProvider = Provider<AccountSession>((ref) {
  return AccountSession(
    data: ref.watch(accountDataServiceProvider),
    pushPendingChanges: () => ref.read(syncEngineProvider).sync(),
    stopSync: () async {
      await ref.read(syncEngineProvider).stop();
      // Summaries and reminders carry this account's amounts.
      try {
        await ref.read(scheduledNoticesServiceProvider).cancelScheduled();
      } catch (e) {
        debugPrint('Could not cancel scheduled notifications: $e');
      }
    },
    discardCapturedNotifications: () async {
      final channel = ref.read(walletCaptureChannelProvider);
      if (!channel.isSupported) return;
      try {
        // Reading the waiting notifications removes them.
        await channel.drain();
      } catch (e) {
        debugPrint('Could not discard captured notifications: $e');
      }
    },
    resetAppState: () => _resetAppState(ref),
  );
});

/// Drops everything the app has loaded for the previous account, so each
/// screen reads the database again.
void _resetAppState(Ref ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(expenseCategoriesProvider);
  ref.invalidate(incomeCategoriesProvider);
  ref.invalidate(categoriesManagerProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(accountsWithBalanceProvider);
  ref.invalidate(budgetsProvider);
  ref.invalidate(loansProvider);
  ref.invalidate(analyticsProvider);
  ref.invalidate(walletCaptureProvider);
  ref.invalidate(recurringRulesProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(sheetSetupProvider);
  ref.invalidate(pendingSyncCountProvider);
  // Settings keep the device preferences; reloading them drops the
  // spreadsheet link if it was removed.
  ref.read(settingsProvider.notifier).loadSettings();
}
