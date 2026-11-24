import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/data/local/local_account_dao.dart';
import 'package:spendsheet/data/local/local_budget_dao.dart';
import 'package:spendsheet/data/local/local_category_dao.dart';
import 'package:spendsheet/data/local/local_goal_dao.dart';
import 'package:spendsheet/data/local/local_loan_dao.dart';
import 'package:spendsheet/data/local/local_person_dao.dart';
import 'package:spendsheet/data/local/local_recurring_dao.dart';
import 'package:spendsheet/data/local/local_transaction_dao.dart';
import 'package:spendsheet/data/local/sync_queue_dao.dart';
import 'package:spendsheet/data/models/goal.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';
import 'package:spendsheet/data/repositories/goal_repository.dart';
import 'package:spendsheet/data/repositories/recurring_repository.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';

import '../../helpers/fake_sheets_service.dart';
import '../../helpers/test_database_helper.dart';

class _OnlineSyncEngine extends SyncEngine {
  _OnlineSyncEngine({
    required super.sheetsService,
    required super.transactionDao,
    required super.categoryDao,
    required super.accountDao,
    required super.budgetDao,
    required super.personDao,
    required super.loanDao,
    required super.syncQueueDao,
  });

  @override
  Future<bool> isOnline() async => true;
}

void main() {
  late FakeSheetsService sheet;
  late _OnlineSyncEngine engine;
  late TransactionRepository transactions;
  late RecurringRepository recurring;
  late GoalRepository goals;
  final transactionDao = LocalTransactionDao();

  setUpAll(() {
    initTestDatabase();
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() => DatabaseHelper.pathOverride = null);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.close();
    sheet = FakeSheetsService();
    engine = _OnlineSyncEngine(
      sheetsService: sheet,
      transactionDao: transactionDao,
      categoryDao: LocalCategoryDao(),
      accountDao: LocalAccountDao(),
      budgetDao: LocalBudgetDao(),
      personDao: LocalPersonDao(),
      loanDao: LocalLoanDao(),
      syncQueueDao: SyncQueueDao(),
    );
    transactions = TransactionRepository(
      localDao: transactionDao,
      syncQueueDao: SyncQueueDao(),
      syncEngine: engine,
    );
    recurring = RecurringRepository(
      dao: LocalRecurringDao(),
      transactionDao: transactionDao,
      syncEngine: engine,
    );
    goals = GoalRepository(dao: LocalGoalDao(), syncEngine: engine);
    await engine.initialize('sheet-1');
  });

  tearDown(() async {
    engine.dispose();
    await DatabaseHelper.instance.close();
  });

  Future<Transaction> rent(DateTime date) => transactions.create(
        amount: 15000,
        type: TransactionType.expense,
        categoryId: 'cat_home',
        accountId: 'acc_bank',
        date: date,
        note: 'Rent',
      );

  group('repeating payments', () {
    test('the rule starts at the occurrence after the first transaction',
        () async {
      final first = await rent(DateTime(2026, 1, 5, 10));
      final rule = await recurring.createFrom(first,
          frequency: RecurringFrequency.monthly, name: 'Rent');

      expect(rule.nextDueDate, DateTime(2026, 2, 5, 10));
      expect(rule.amount, 15000);
      expect(rule.isActive, isTrue);
    });

    test('due occurrences are added once each and the rule moves on',
        () async {
      final first = await rent(DateTime(2026, 1, 5, 10));
      final rule = await recurring.createFrom(first,
          frequency: RecurringFrequency.monthly, name: 'Rent');

      final added = await recurring.processDue(DateTime(2026, 3, 20));
      expect(added, 2, reason: 'February and March');
      expect(await recurring.processDue(DateTime(2026, 3, 20)), 0);

      final feb = await transactionDao.getById(
          RecurringRepository.occurrenceId(rule.id, DateTime(2026, 2, 5)));
      expect(feb, isNotNull);
      expect(feb!.amount, 15000);
      expect(feb.recurringId, rule.id);
      expect(feb.note, 'Rent');
      expect((await recurring.getById(rule.id))!.nextDueDate,
          DateTime(2026, 4, 5, 10));
    });

    test('an occurrence the user deleted is not added again', () async {
      final first = await rent(DateTime(2026, 1, 5));
      final rule = await recurring.createFrom(first,
          frequency: RecurringFrequency.monthly, name: 'Rent');
      await recurring.processDue(DateTime(2026, 2, 6));
      final id =
          RecurringRepository.occurrenceId(rule.id, DateTime(2026, 2, 5));
      await transactions.delete(id);

      // The rule is set back, as when another phone had not moved it on.
      final current = (await recurring.getById(rule.id))!;
      await recurring.update(current.copyWith(nextDueDate: DateTime(2026, 2, 5)));
      expect(await recurring.processDue(DateTime(2026, 2, 6)), 0);
      expect((await transactionDao.getById(id))!.isDeleted, isTrue);
    });

    test('a paused rule adds nothing', () async {
      final first = await rent(DateTime(2026, 1, 5));
      final rule = await recurring.createFrom(first,
          frequency: RecurringFrequency.weekly, name: 'Rent');
      await recurring.setActive(rule, false);

      expect(await recurring.processDue(DateTime(2026, 6, 1)), 0);
    });

    test('a rule stops after its end date', () async {
      final first = await rent(DateTime(2026, 1, 5));
      final rule = await recurring.createFrom(first,
          frequency: RecurringFrequency.monthly, name: 'Rent');
      await recurring.update(rule.copyWith(endDate: DateTime(2026, 3, 5)));

      expect(await recurring.processDue(DateTime(2026, 8, 1)), 2);
      expect((await recurring.getById(rule.id))!.isActive, isFalse);
    });

    test('catching up is capped', () async {
      final first = await rent(DateTime(2020, 1, 1));
      await recurring.createFrom(first,
          frequency: RecurringFrequency.daily, name: 'Coffee');

      expect(await recurring.processDue(DateTime(2026, 1, 1)),
          RecurringRepository.maxCatchUp);
    });

    test('rules and their transactions reach the sheet', () async {
      final first = await rent(DateTime(2026, 1, 5));
      final rule = await recurring.createFrom(first,
          frequency: RecurringFrequency.monthly, name: 'Rent');
      await recurring.processDue(DateTime(2026, 2, 6));
      await engine.sync();

      expect(sheet.recurring.byId(rule.id)?.nextDueDate,
          DateTime(2026, 3, 5));
      expect(
          sheet.transactions.countOf(
              RecurringRepository.occurrenceId(rule.id, DateTime(2026, 2, 5))),
          1);
    });

    test('rules on the sheet are pulled to the phone', () async {
      final now = DateTime(2026, 1, 1);
      sheet.recurring.rows.add(RecurringRule(
        id: 'r-sheet',
        name: 'Netflix',
        amount: 649,
        type: TransactionType.expense,
        categoryId: 'cat_subscriptions',
        accountId: 'acc_credit',
        frequency: RecurringFrequency.monthly,
        nextDueDate: DateTime(2026, 2, 1),
        createdAt: now,
        updatedAt: now,
      ));
      await engine.sync();

      expect((await recurring.getAll()).single.name, 'Netflix');
    });
  });

  group('savings goals', () {
    test('saved money is added and taken out, never below zero', () async {
      var goal = await goals.create(
        name: ' New phone ',
        targetAmount: 60000,
        icon: '📱',
        color: 0xFF0E6E7A,
      );
      expect(goal.name, 'New phone');

      goal = await goals.addToSaved(goal, 18000);
      expect(goal.savedAmount, 18000);
      expect(goal.progress, closeTo(0.3, 1e-9));

      goal = await goals.addToSaved(goal, -50000);
      expect(goal.savedAmount, 0);
    });

    test('goals sync both ways', () async {
      final goal = await goals.create(
          name: 'Trip', targetAmount: 1000, icon: '✈️', color: 1);
      await engine.sync();
      expect(sheet.goals.byId(goal.id)?.name, 'Trip');

      sheet.goals.rows.add(Goal(
        id: 'g-sheet',
        name: 'Laptop',
        targetAmount: 900,
        icon: '💻',
        color: 2,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
      await engine.sync();
      expect((await goals.getAll()).map((g) => g.name), ['Laptop', 'Trip']);
    });

    test('a deleted goal leaves the list', () async {
      final goal = await goals.create(
          name: 'Trip', targetAmount: 1000, icon: '✈️', color: 1);
      await goals.delete(goal.id);

      expect(await goals.getAll(), isEmpty);
    });
  });

  group('labels', () {
    test('are cleaned up when saved', () async {
      final t = await transactions.create(
        amount: 10,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        labels: ['  Goa   trip ', 'goa trip', 'Wed,ding', ''],
      );

      expect((await transactionDao.getById(t.id))!.labels,
          ['Goa trip', 'Wed ding']);
    });

    test('can be listed, searched and totalled', () async {
      Future<void> add(double amount, List<String> labels,
          {TransactionType type = TransactionType.expense}) async {
        await transactions.create(
          amount: amount,
          type: type,
          categoryId: 'cat_food',
          accountId: 'acc_cash',
          date: DateTime(2026, 3, 10),
          labels: labels,
        );
      }

      await add(100, ['Goa trip']);
      await add(50, ['goa trip', 'Food']);
      await add(30, ['Goa']);
      await add(999, ['Goa trip'], type: TransactionType.income);

      expect(await transactions.getAllLabels(), ['Goa trip', 'Food', 'Goa']);
      expect((await transactions.getByLabel('GOA TRIP')).length, 3);
      expect((await transactions.getByLabel('Goa')).length, 1,
          reason: 'a label is matched whole, not as part of another');

      final totals = await transactions.getExpenseTotalsByLabel(
          DateTime(2026, 3, 1), DateTime(2026, 3, 31, 23, 59));
      expect(totals, {'Goa trip': 150, 'Food': 50, 'Goa': 30});
    });

    test('survive the trip through a sheet row', () {
      final t = Transaction(
        id: 't',
        date: DateTime(2026),
        amount: 1,
        type: TransactionType.expense,
        categoryId: 'c',
        accountId: 'a',
        labels: const ['Goa trip', 'Work'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final row = t.toSheetRow();
      expect(row['labels'], 'Goa trip, Work');

      final back = Transaction.fromSheetRow([
        't', '2026-01-01T00:00:00.000', '1', 'expense', 'c', 'a', '', '', '',
        '', '2026-01-01T00:00:00.000', '2026-01-01T00:00:00.000', '',
        'Goa trip, Work',
      ]);
      expect(back.labels, ['Goa trip', 'Work']);

      // Rows written before labels existed have no such cell.
      final old = Transaction.fromSheetRow([
        't', '2026-01-01T00:00:00.000', '1', 'expense', 'c', 'a',
      ]);
      expect(old.labels, isEmpty);
    });
  });

  test('Goal.monthlyToReach spreads what is left over the months to go', () {
    final goal = Goal(
      id: 'g',
      name: 'Phone',
      targetAmount: 60000,
      savedAmount: 18000,
      targetDate: DateTime(2026, 7, 15),
      icon: '📱',
      color: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    // 15 Jan to 15 Jul: six months for 42,000.
    expect(goal.monthlyToReach(DateTime(2026, 1, 15)), 7000);
    expect(goal.monthlyToReach(DateTime(2026, 8, 1)), isNull);
    expect(goal.copyWith(targetDate: null).monthlyToReach(DateTime(2026)),
        isNull);
  });
}
