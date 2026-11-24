import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/core/services/notification_service.dart';
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/data/local/local_category_dao.dart';
import 'package:spendsheet/data/local/local_recurring_dao.dart';
import 'package:spendsheet/data/local/local_transaction_dao.dart';
import 'package:spendsheet/data/local/sync_queue_dao.dart';
import 'package:spendsheet/data/models/app_settings.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/repositories/recurring_repository.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';
import 'package:spendsheet/features/notices/scheduled_notices_service.dart';

import '../../helpers/mock_repositories.dart';
import '../../helpers/mock_sync_engine.dart';
import '../../helpers/test_database_helper.dart';

typedef Scheduled = ({int id, DateTime when, String title, String body});

/// Records what would be scheduled.
class _Notifications extends NotificationService {
  final reminders = <Scheduled>[];
  final summaries = <Scheduled>[];
  final cancelled = <int>[];

  @override
  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async =>
      reminders.add((id: id, when: when, title: title, body: body));

  @override
  Future<void> scheduleSummary({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async =>
      summaries.add((id: id, when: when, title: title, body: body));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

void main() {
  group('SummaryPeriod', () {
    test('a month arrives on the morning of the 1st', () {
      final p = SummaryPeriod.containing(
          DateTime(2026, 11, 24, 15), SummaryFrequency.monthly);
      expect(p.start, DateTime(2026, 11));
      expect(p.deliverAt, DateTime(2026, 12, 1, 9));
      expect(p.previous.start, DateTime(2026, 10));
    });

    test('a week runs Monday to Sunday and arrives Monday morning', () {
      // 24 Nov 2026 is a Tuesday.
      final p = SummaryPeriod.containing(
          DateTime(2026, 11, 24), SummaryFrequency.weekly);
      expect(p.start, DateTime(2026, 11, 23));
      expect(p.deliverAt, DateTime(2026, 11, 30, 9));
      expect(p.rangeLabel, '23–29 Nov');
      expect(p.previous.start, DateTime(2026, 11, 16));
    });

    test('each period has its own notification id', () {
      final nov = SummaryPeriod.containing(
          DateTime(2026, 11, 2), SummaryFrequency.monthly);
      expect(nov.notificationId, isNot(nov.previous.notificationId));
    });
  });

  group('summary text', () {
    final nov = SummaryPeriod.containing(
        DateTime(2026, 11, 5), SummaryFrequency.monthly);

    test('compares with the month before and names the top category', () {
      final text = ScheduledNoticesService.summaryText(
        period: nov,
        spent: 42300,
        spentBefore: 46000,
        topCategory: 'Food & Dining',
        topAmount: 12000,
        currency: 'INR',
      );
      expect(text.title, 'Your November spending');
      expect(text.body,
          '₹42,300.00 spent, 8% less than October. Most went on Food & Dining (₹12,000.00).');
    });

    test('says when nothing was spent', () {
      final text = ScheduledNoticesService.summaryText(
        period: nov,
        spent: 0,
        spentBefore: 100,
        topCategory: null,
        topAmount: 0,
        currency: 'USD',
      );
      expect(text.body, 'No expenses recorded in November.');
    });
  });

  group('reschedule', () {
    late MockSettingsRepository settings;
    late _Notifications notifications;
    late TransactionRepository transactions;
    late RecurringRepository recurring;
    late DateTime now;
    late ScheduledNoticesService service;
    final transactionDao = LocalTransactionDao();

    setUpAll(() {
      initTestDatabase();
      DatabaseHelper.pathOverride = inMemoryDatabasePath;
    });

    tearDownAll(() => DatabaseHelper.pathOverride = null);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await DatabaseHelper.instance.close();
      settings = MockSettingsRepository();
      when(() => settings.getSettings()).thenAnswer(
          (_) async => const AppSettings(currency: 'USD'));
      notifications = _Notifications();
      final sync = MockSyncEngine();
      when(() => sync.queueOperation(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            data: any(named: 'data'),
          )).thenAnswer((_) async {});
      transactions = TransactionRepository(
        localDao: transactionDao,
        syncQueueDao: SyncQueueDao(),
        syncEngine: sync,
      );
      recurring = RecurringRepository(
        dao: LocalRecurringDao(),
        transactionDao: transactionDao,
        syncEngine: sync,
      );
      now = DateTime(2026, 11, 24, 12);
      service = ScheduledNoticesService(
        settings: settings,
        notifications: notifications,
        transactions: transactions,
        recurring: recurring,
        categories: LocalCategoryDao(),
        now: () => now,
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await DatabaseHelper.instance.close();
    });

    Future<void> spend(double amount, DateTime date,
        {String category = 'cat_food'}) async {
      await transactions.create(
        amount: amount,
        type: TransactionType.expense,
        categoryId: category,
        accountId: 'acc_cash',
        date: date,
      );
    }

    test('schedules this month\'s summary for the 1st', () async {
      await spend(100, DateTime(2026, 11, 3));
      await spend(40, DateTime(2026, 10, 3));

      await service.reschedule();

      final s = notifications.summaries.single;
      expect(s.when, DateTime(2026, 12, 1, 9));
      expect(s.title, 'Your November spending');
      expect(s.body, contains('\$100.00 spent, 150% more than October'));
      expect(s.body, contains('Food & Dining'));
    });

    test('early on the 1st, last month\'s summary is kept as well', () async {
      now = DateTime(2026, 12, 1, 7);
      await spend(100, DateTime(2026, 11, 3));

      await service.reschedule();

      expect(notifications.summaries.map((s) => s.title),
          ['Your November spending', 'Your December spending']);
    });

    test('nothing is scheduled when notifications are off', () async {
      when(() => settings.getSettings()).thenAnswer((_) async =>
          const AppSettings(currency: 'USD', notificationsEnabled: false));
      await spend(100, DateTime(2026, 11, 3));

      await service.reschedule();

      expect(notifications.summaries, isEmpty);
      expect(notifications.reminders, isEmpty);
    });

    test('the summary can be weekly or off', () async {
      await spend(100, DateTime(2026, 11, 24));

      await ScheduledNoticesService.setSummaryFrequency(
          SummaryFrequency.weekly);
      await service.reschedule();
      expect(notifications.summaries.single.when, DateTime(2026, 11, 30, 9));

      notifications.summaries.clear();
      await ScheduledNoticesService.setSummaryFrequency(SummaryFrequency.off);
      await service.reschedule();
      expect(notifications.summaries, isEmpty);
    });

    test('reminds the morning before a repeating expense', () async {
      final first = await transactions.create(
        amount: 15000,
        type: TransactionType.expense,
        categoryId: 'cat_home',
        accountId: 'acc_bank',
        date: DateTime(2026, 11, 5, 10),
        note: 'Rent',
      );
      await recurring.createFrom(first,
          frequency: RecurringFrequency.monthly, name: 'Rent');

      await service.reschedule();

      final r = notifications.reminders.single;
      expect(r.when, DateTime(2026, 12, 4, 9));
      expect(r.title, 'Rent is due tomorrow');
      expect(r.body, startsWith('\$15,000.00.'));

      await ScheduledNoticesService.setRemindersEnabled(false);
      notifications.reminders.clear();
      await service.reschedule();
      expect(notifications.reminders, isEmpty);
    });

    test('rescheduling and signing out withdraw what was scheduled',
        () async {
      await spend(100, DateTime(2026, 11, 3));
      await service.reschedule();
      final id = notifications.summaries.single.id;

      await service.reschedule();
      expect(notifications.cancelled, [id]);

      notifications.cancelled.clear();
      await service.cancelScheduled();
      expect(notifications.cancelled, [id]);

      notifications.cancelled.clear();
      await service.cancelScheduled();
      expect(notifications.cancelled, isEmpty);
    });
  });
}
