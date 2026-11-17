import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/budget.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../onboarding/providers/sheet_setup_provider.dart';

final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  return BudgetAlertService(
    settings: ref.watch(settingsRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});

/// How far a budget's spending has gone, as far as alerts are concerned.
enum BudgetAlertLevel { none, nearLimit, reached }

/// Notifies the user when a budget's spending reaches 80% and again at
/// 100%, at most once per level in each budget period.
class BudgetAlertService {
  BudgetAlertService({
    required SettingsRepository settings,
    required NotificationService notifications,
    DateTime Function()? now,
  })  : _settings = settings,
        _notifications = notifications,
        _now = now ?? DateTime.now;

  final SettingsRepository _settings;
  final NotificationService _notifications;
  final DateTime Function() _now;

  static const _keyPrefix = 'budget_alert.';

  static BudgetAlertLevel levelFor(Budget budget) {
    if (budget.amount <= 0) return BudgetAlertLevel.none;
    final used = budget.percentUsed;
    if (used >= AppConstants.budgetCriticalThreshold) {
      return BudgetAlertLevel.reached;
    }
    if (used >= AppConstants.budgetWarningThreshold) {
      return BudgetAlertLevel.nearLimit;
    }
    return BudgetAlertLevel.none;
  }

  /// Sends the alerts that [budgets] call for. Their `spentAmount` must be
  /// up to date for the current period, as `BudgetRepository.getAll` gives.
  Future<void> check(List<Budget> budgets) async {
    final settings = await _settings.getSettings();
    if (!settings.notificationsEnabled || !settings.budgetAlertsEnabled) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = _now();

    for (final budget in budgets) {
      if (budget.isDeleted) continue;

      final key = _sentKey(budget, now);
      final sent = prefs.getInt(key) ?? BudgetAlertLevel.none.index;
      final level = levelFor(budget);

      if (level.index > sent) {
        try {
          await _notifications.showBudgetAlert(
            id: _notificationId(budget.id),
            title: _title(budget, level),
            body: _body(budget, settings.currency),
          );
        } catch (e) {
          debugPrint('Budget alert for ${budget.id} failed: $e');
          continue; // not recorded, so the next check tries again
        }
        await _record(prefs, budget, key, level);
      } else if (level.index < sent) {
        // Spending fell back (an expense was removed or the budget was
        // raised), so alert again if it climbs past the level once more.
        await _record(prefs, budget, key, level);
      }
    }
  }

  /// Stores the level alerted for [budget] in this period, and forgets the
  /// levels stored for its earlier periods.
  Future<void> _record(
    SharedPreferences prefs,
    Budget budget,
    String key,
    BudgetAlertLevel level,
  ) async {
    final budgetPrefix = '$_keyPrefix${budget.id}.';
    for (final old in prefs.getKeys().where(
          (k) => k.startsWith(budgetPrefix) && k != key,
        )) {
      await prefs.remove(old);
    }
    await prefs.setInt(key, level.index);
  }

  String _sentKey(Budget budget, DateTime now) {
    final start = switch (budget.period) {
      BudgetPeriod.weekly => AppDateUtils.startOfWeek(now),
      BudgetPeriod.monthly => AppDateUtils.startOfMonth(now),
      BudgetPeriod.yearly => AppDateUtils.startOfYear(now),
    };
    final day = '${start.year}-${start.month}-${start.day}';
    return '$_keyPrefix${budget.id}.$day';
  }

  /// A stable notification ID per budget, so a newer alert replaces the
  /// older one instead of stacking up.
  static int _notificationId(String budgetId) {
    var hash = 0;
    for (final unit in budgetId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static String _title(Budget budget, BudgetAlertLevel level) {
    final name = budget.name.trim().isEmpty ? 'Your' : budget.name.trim();
    if (level == BudgetAlertLevel.nearLimit) {
      final percent = (budget.percentUsed * 100).floor();
      return '$name budget at $percent%';
    }
    return budget.isOverBudget
        ? '$name budget exceeded'
        : '$name budget used up';
  }

  static String _body(Budget budget, String currency) {
    String money(double value) =>
        CurrencyUtils.format(value, currencyCode: currency);
    final period = switch (budget.period) {
      BudgetPeriod.weekly => 'this week',
      BudgetPeriod.monthly => 'this month',
      BudgetPeriod.yearly => 'this year',
    };
    final spent =
        "You've spent ${money(budget.spentAmount)} of ${money(budget.amount)} $period";
    if (budget.isOverBudget) {
      return '$spent, ${money(-budget.remaining)} over.';
    }
    if (budget.remaining > 0) {
      return '$spent. ${money(budget.remaining)} left.';
    }
    return '$spent.';
  }
}
