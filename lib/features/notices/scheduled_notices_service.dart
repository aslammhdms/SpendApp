import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/local_category_dao.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/recurring_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../home/providers/dashboard_provider.dart';
import '../onboarding/providers/sheet_setup_provider.dart';
import '../recurring/providers/recurring_provider.dart';

/// How often a spending summary arrives.
enum SummaryFrequency { off, weekly, monthly }

final scheduledNoticesServiceProvider =
    Provider<ScheduledNoticesService>((ref) {
  return ScheduledNoticesService(
    settings: ref.watch(settingsRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    recurring: ref.watch(recurringRepositoryProvider),
    categories: ref.watch(localCategoryDaoProvider),
  );
});

/// Spending summaries and reminders before repeating payments.
///
/// Android shows them at their time even when the app is closed, so they
/// are scheduled ahead and scheduled again whenever the data changes (each
/// time Home refreshes). A summary therefore counts what this phone knew
/// at its last refresh before the period ended.
class ScheduledNoticesService {
  ScheduledNoticesService({
    required SettingsRepository settings,
    required NotificationService notifications,
    required TransactionRepository transactions,
    required RecurringRepository recurring,
    required LocalCategoryDao categories,
    DateTime Function()? now,
  })  : _settings = settings,
        _notifications = notifications,
        _transactions = transactions,
        _recurring = recurring,
        _categories = categories,
        _now = now ?? DateTime.now;

  final SettingsRepository _settings;
  final NotificationService _notifications;
  final TransactionRepository _transactions;
  final RecurringRepository _recurring;
  final LocalCategoryDao _categories;
  final DateTime Function() _now;

  static const _summaryKey = 'notices.summary';
  static const _remindersKey = 'notices.recurring_reminders';
  static const _scheduledKey = 'notices.scheduled_ids';

  /// The hour of the morning summaries and reminders arrive.
  static const int hour = 9;

  /// At most this many repeating-payment reminders are waiting at once.
  static const int maxReminders = 20;

  static Future<SummaryFrequency> summaryFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_summaryKey);
    return SummaryFrequency.values.firstWhere(
      (f) => f.name == stored,
      orElse: () => SummaryFrequency.monthly,
    );
  }

  static Future<void> setSummaryFrequency(SummaryFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_summaryKey, frequency.name);
  }

  static Future<bool> remindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersKey) ?? true;
  }

  static Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, enabled);
  }

  /// Replaces whatever was scheduled before with what the current data and
  /// settings call for.
  Future<void> reschedule() async {
    await cancelScheduled();
    final prefs = await SharedPreferences.getInstance();

    final scheduled = <int>[];
    try {
      final settings = await _settings.getSettings();
      if (settings.notificationsEnabled) {
        final currency = settings.currency;
        if (await remindersEnabled()) {
          scheduled.addAll(await _scheduleReminders(currency));
        }
        final frequency = await summaryFrequency();
        if (frequency != SummaryFrequency.off) {
          scheduled.addAll(await _scheduleSummaries(frequency, currency));
        }
      }
    } finally {
      await prefs.setStringList(
        _scheduledKey,
        [for (final id in scheduled) id.toString()],
      );
    }
  }

  /// Withdraws every summary and reminder still waiting, as when the
  /// account signs out: they carry that account's amounts.
  Future<void> cancelScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in prefs.getStringList(_scheduledKey) ?? const <String>[]) {
      final parsed = int.tryParse(id);
      if (parsed == null) continue;
      try {
        await _notifications.cancel(parsed);
      } catch (e) {
        debugPrint('Could not cancel notification $parsed: $e');
      }
    }
    await prefs.remove(_scheduledKey);
  }

  /// Two notices for each repeating expense: one the morning before it is
  /// due, one on the morning itself.
  ///
  /// When the morning before has already passed (a payment set up today
  /// for tomorrow), that reminder is sent a minute from now instead, once.
  Future<List<int>> _scheduleReminders(String currency) async {
    final now = _now();
    final prefs = await SharedPreferences.getInstance();
    final rules = (await _recurring.getAll())
        .where((r) => r.isActive && !r.isDeleted)
        .where((r) => r.type == TransactionType.expense)
        .take(maxReminders);
    final ids = <int>[];
    final lateKeys = <String>{};
    for (final rule in rules) {
      final due = rule.nextDueDate;
      final dueDay = DateTime(due.year, due.month, due.day);

      var before = DateTime(due.year, due.month, due.day - 1, hour);
      if (!before.isAfter(now) && dueDay.isAfter(now)) {
        // Too late for 9am. Send it shortly, and keep to that time on
        // later calls so it is neither lost nor sent twice.
        final key = '$_lateKeyPrefix${rule.id}.${dueDay.toIso8601String()}';
        lateKeys.add(key);
        final stored = DateTime.tryParse(prefs.getString(key) ?? '');
        before = stored ?? now.add(lateReminderDelay);
        if (stored == null) {
          await prefs.setString(key, before.toIso8601String());
        }
      }
      if (before.isAfter(now)) {
        final id = reminderId(rule.id);
        await _notifications.scheduleReminder(
          id: id,
          when: before,
          title: reminderTitle(rule),
          body: reminderBody(rule, currency),
        );
        ids.add(id);
      }

      final onTheDay = DateTime(due.year, due.month, due.day, hour);
      if (onTheDay.isAfter(now)) {
        final id = dueTodayId(rule.id);
        await _notifications.scheduleReminder(
          id: id,
          when: onTheDay,
          title: dueTodayTitle(rule),
          body: dueTodayBody(rule, currency),
        );
        ids.add(id);
      }
    }
    // Forget late reminders of payments that have since moved on.
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_lateKeyPrefix) && !lateKeys.contains(key)) {
        await prefs.remove(key);
      }
    }
    return ids;
  }

  static const _lateKeyPrefix = 'notices.late_reminder.';

  /// How soon a reminder that missed its morning is sent.
  static const Duration lateReminderDelay = Duration(minutes: 1);

  /// Sends a reminder about a minute from now, through the same scheduling
  /// as the real ones, so the user can see that they arrive on this phone.
  /// Returns false when notifications are off or blocked.
  Future<bool> sendTestReminder() async {
    final settings = await _settings.getSettings();
    if (!settings.notificationsEnabled) return false;
    if (!await _notifications.areEnabled()) return false;
    await _notifications.scheduleReminder(
      id: _testId,
      when: _now().add(lateReminderDelay),
      title: 'Test reminder',
      body: 'Reminders from SpendSheet arrive on this phone.',
    );
    return true;
  }

  static const int _testId = 0x54000001;

  Future<List<int>> _scheduleSummaries(
    SummaryFrequency frequency,
    String currency,
  ) async {
    final now = _now();
    final current = SummaryPeriod.containing(now, frequency);
    final ids = <int>[];
    // The period that just ended, when its summary is not due yet (Home
    // opened early on the 1st), then the current one.
    for (final period in [current.previous, current]) {
      final when = period.deliverAt;
      if (!when.isAfter(now)) continue;
      final text = await summaryFor(period, currency);
      if (text == null) continue;
      await _notifications.scheduleSummary(
        id: period.notificationId,
        when: when,
        title: text.title,
        body: text.body,
      );
      ids.add(period.notificationId);
    }
    return ids;
  }

  /// The summary of [period], or null when nothing was spent in it or in
  /// the period before.
  Future<({String title, String body})?> summaryFor(
    SummaryPeriod period,
    String currency,
  ) async {
    final spent = await _transactions.getTotalByTypeAndDateRange(
        TransactionType.expense, period.start, period.end);
    final before = period.previous;
    final spentBefore = await _transactions.getTotalByTypeAndDateRange(
        TransactionType.expense, before.start, before.end);
    if (spent <= 0 && spentBefore <= 0) return null;

    String? topName;
    double topAmount = 0;
    final byCategory =
        await _transactions.getTotalsByCategory(period.start, period.end);
    for (final entry in byCategory.entries) {
      if (entry.value > topAmount) {
        topAmount = entry.value;
        topName = entry.key;
      }
    }
    if (topName != null) {
      topName = _clean((await _categories.getById(topName))?.name);
    }

    return summaryText(
      period: period,
      spent: spent,
      spentBefore: spentBefore,
      topCategory: topName,
      topAmount: topAmount,
      currency: currency,
    );
  }

  @visibleForTesting
  static ({String title, String body}) summaryText({
    required SummaryPeriod period,
    required double spent,
    required double spentBefore,
    required String? topCategory,
    required double topAmount,
    required String currency,
  }) {
    String money(double v) =>
        CurrencyUtils.format(v, currencyCode: currency, plain: true);
    final title = period.frequency == SummaryFrequency.monthly
        ? 'Your ${DateFormat('MMMM').format(period.start)} spending'
        : 'Your spending, ${period.rangeLabel}';

    if (spent <= 0) {
      return (
        title: title,
        body: 'No expenses recorded ${period.inLabel}.',
      );
    }
    final parts = <String>['${money(spent)} spent'];
    if (spentBefore > 0) {
      final change = ((spent - spentBefore) / spentBefore * 100).round();
      final versus = period.previous.versusLabel;
      if (change == 0) {
        parts.add('about the same as $versus');
      } else if (change > 0) {
        parts.add('$change% more than $versus');
      } else {
        parts.add('${-change}% less than $versus');
      }
    }
    var body = '${parts.join(', ')}.';
    if (topCategory != null && topCategory.isNotEmpty) {
      body += ' Most went on $topCategory (${money(topAmount)}).';
    }
    return (title: title, body: body);
  }

  static String? _clean(String? name) {
    if (name == null) return null;
    var cleaned = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
    if (cleaned.length > 40) cleaned = '${cleaned.substring(0, 40)}…';
    return cleaned;
  }

  @visibleForTesting
  static String reminderTitle(RecurringRule rule) {
    final name = _clean(rule.name);
    return '${name == null || name.isEmpty ? 'A repeating payment' : name} '
        'is due tomorrow';
  }

  @visibleForTesting
  static String reminderBody(RecurringRule rule, String currency) {
    final amount = CurrencyUtils.format(
        rule.amount,
        currencyCode: currency,
        plain: true);
    return '$amount. SpendSheet adds it as an expense when it falls due.';
  }

  @visibleForTesting
  static String dueTodayTitle(RecurringRule rule) {
    final name = _clean(rule.name);
    return '${name == null || name.isEmpty ? 'A repeating payment' : name} '
        'is due today';
  }

  @visibleForTesting
  static String dueTodayBody(RecurringRule rule, String currency) {
    final amount = CurrencyUtils.format(
        rule.amount,
        currencyCode: currency,
        plain: true);
    return '$amount. Open SpendSheet and it is added as an expense.';
  }

  /// The ID of a rule's "due today" notice, in a block of its own.
  @visibleForTesting
  static int dueTodayId(String ruleId) =>
      reminderId(ruleId) - 0x50000000 + 0x53000000;

  /// Reminder IDs sit in their own block, apart from the summaries.
  @visibleForTesting
  static int reminderId(String ruleId) {
    var hash = 0;
    for (final unit in ruleId.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFFF;
    }
    return 0x50000000 + hash;
  }
}

/// A week or a month that a summary covers.
class SummaryPeriod {
  SummaryPeriod._(this.frequency, this.start, this.end);

  factory SummaryPeriod.containing(DateTime day, SummaryFrequency frequency) {
    if (frequency == SummaryFrequency.weekly) {
      final start = AppDateUtils.startOfDay(AppDateUtils.startOfWeek(day));
      return SummaryPeriod._(
        frequency,
        start,
        DateTime(start.year, start.month, start.day + 7)
            .subtract(const Duration(microseconds: 1)),
      );
    }
    return SummaryPeriod._(
      SummaryFrequency.monthly,
      DateTime(day.year, day.month),
      DateTime(day.year, day.month + 1)
          .subtract(const Duration(microseconds: 1)),
    );
  }

  final SummaryFrequency frequency;
  final DateTime start;
  final DateTime end;

  SummaryPeriod get previous => SummaryPeriod.containing(
      start.subtract(const Duration(days: 1)), frequency);

  /// The morning after the period ends.
  DateTime get deliverAt {
    final next = end.add(const Duration(microseconds: 1));
    return DateTime(
        next.year, next.month, next.day, ScheduledNoticesService.hour);
  }

  /// One ID per period, so the summary of a period replaces itself but not
  /// the summary of the period before.
  int get notificationId {
    final days = DateTime.utc(start.year, start.month, start.day)
            .millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final block = frequency == SummaryFrequency.weekly ? 0x52000000 : 0x51000000;
    return block + days;
  }

  /// "17–23 Nov".
  String get rangeLabel {
    final last = AppDateUtils.startOfDay(end);
    if (start.month == last.month) {
      return '${start.day}–${DateFormat('d MMM').format(last)}';
    }
    return '${DateFormat('d MMM').format(start)} – '
        '${DateFormat('d MMM').format(last)}';
  }

  /// "in November" or "this week" style phrase for the period itself.
  String get inLabel => frequency == SummaryFrequency.monthly
      ? 'in ${DateFormat('MMMM').format(start)}'
      : 'from $rangeLabel';

  /// How the period is named when compared against: "October", "the week
  /// before".
  String get versusLabel => frequency == SummaryFrequency.monthly
      ? DateFormat('MMMM').format(start)
      : 'the week before';
}
