import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/core/constants/category_defaults.dart';
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/data/local/local_account_dao.dart';
import 'package:spendsheet/data/local/local_budget_dao.dart';
import 'package:spendsheet/data/local/local_category_dao.dart';
import 'package:spendsheet/data/local/local_loan_dao.dart';
import 'package:spendsheet/data/local/local_person_dao.dart';
import 'package:spendsheet/data/local/local_transaction_dao.dart';
import 'package:spendsheet/data/local/sync_queue_dao.dart';
import 'package:spendsheet/data/models/account.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';

import '../../helpers/fake_sheets_service.dart';
import '../../helpers/test_database_helper.dart';

/// A sync engine whose connectivity the test controls.
class _TestSyncEngine extends SyncEngine {
  bool online = true;

  _TestSyncEngine({
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
  Future<bool> isOnline() async => online;
}

void main() {
  late FakeSheetsService sheet;
  late _TestSyncEngine engine;
  late TransactionRepository transactions;

  final transactionDao = LocalTransactionDao();
  final categoryDao = LocalCategoryDao();
  final accountDao = LocalAccountDao();
  final queueDao = SyncQueueDao();

  setUpAll(() {
    initTestDatabase();
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() {
    DatabaseHelper.pathOverride = null;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Closing the in-memory database discards it, so each test starts from
    // a fresh install: schema plus the built-in categories and accounts.
    await DatabaseHelper.instance.close();

    sheet = FakeSheetsService();
    engine = _TestSyncEngine(
      sheetsService: sheet,
      transactionDao: transactionDao,
      categoryDao: categoryDao,
      accountDao: accountDao,
      budgetDao: LocalBudgetDao(),
      personDao: LocalPersonDao(),
      loanDao: LocalLoanDao(),
      syncQueueDao: queueDao,
    );
    transactions = TransactionRepository(
      localDao: transactionDao,
      syncQueueDao: queueDao,
      syncEngine: engine,
    );
    await engine.initialize('sheet-1');
  });

  tearDown(() async {
    engine.dispose();
    await DatabaseHelper.instance.close();
  });

  /// Puts the built-in categories and accounts on the sheet, the way a
  /// spreadsheet created by this version starts out.
  Future<void> seedSheetWithDefaults() async {
    sheet.categories.rows.addAll(await categoryDao.getAll());
    sheet.accounts.rows.addAll(await accountDao.getAll());
  }

  /// Puts the built-in categories and accounts on the sheet under random
  /// IDs, the way spreadsheets created by earlier versions started out.
  void seedSheetLikeOldVersion() {
    final now = DateTime(2026, 1, 1);
    for (final d in CategoryDefaults.expenseCategories) {
      sheet.categories.rows.add(Category(
        id: 'old-${d.id}',
        name: d.name,
        type: CategoryType.expense,
        icon: d.icon,
        color: d.color,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
    for (final d in CategoryDefaults.defaultAccounts) {
      sheet.accounts.rows.add(Account(
        id: 'old-${d.id}',
        name: d.name,
        type: AccountType.values.byName(d.type),
        initialBalance: 0,
        currency: 'USD',
        icon: d.icon,
        color: d.color,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  Future<Transaction> recordExpense({
    double amount = 12.5,
    String categoryId = 'cat_food',
    String accountId = 'acc_cash',
  }) {
    return transactions.create(
      amount: amount,
      type: TransactionType.expense,
      categoryId: categoryId,
      accountId: accountId,
    );
  }

  Future<int> queuedCount() async => (await queueDao.getAll()).length;

  group('full sync keeps changes that have not reached the sheet', () {
    setUp(seedSheetWithDefaults);

    test('pushes an expense recorded offline before rebuilding local data',
        () async {
      engine.online = false;
      final expense = await recordExpense();

      engine.online = true;
      await engine.fullSync();

      expect(await transactionDao.getById(expense.id), isNotNull);
      expect(sheet.transactions.countOf(expense.id), 1);
      expect(await queuedCount(), 0);
    });

    test('keeps the local copy and the queue entry when the push fails',
        () async {
      engine.online = false;
      final expense = await recordExpense();
      sheet.failingIds.add(expense.id);

      engine.online = true;
      await engine.fullSync();

      expect(await transactionDao.getById(expense.id), isNotNull);
      expect(sheet.transactions.rows, isEmpty);
      expect(await queuedCount(), 1);
      expect(engine.currentStatus, SyncStatus.pending);

      sheet.failingIds.clear();
      await engine.sync();

      expect(sheet.transactions.countOf(expense.id), 1);
      expect(await queuedCount(), 0);
    });

    test('retries a change that already used up its retries', () async {
      final expense = await recordExpense();
      sheet.failingIds.add(expense.id);
      for (var i = 0; i < 3; i++) {
        await engine.sync();
      }
      expect(await engine.getPendingCount(), 0,
          reason: 'three failures take it out of normal syncs');

      sheet.failingIds.clear();
      await engine.fullSync();

      expect(sheet.transactions.countOf(expense.id), 1);
      expect(await transactionDao.getById(expense.id), isNotNull);
    });

    test('still drops local rows that are gone from the sheet', () async {
      final now = DateTime(2026, 11, 1);
      final removedOnSheet = Transaction(
        id: 'removed-elsewhere',
        date: now,
        amount: 5,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        createdAt: now,
        updatedAt: now,
      );
      await transactionDao.insert(removedOnSheet); // synced, not queued

      await engine.fullSync();

      expect(await transactionDao.getById('removed-elsewhere'), isNull);
    });

    test('does not overlap a sync that is already pushing', () async {
      final expense = await recordExpense();
      sheet.appendGate = Completer<void>();

      final running = engine.sync(); // blocks inside the append
      await pumpEventQueue();
      final full = engine.fullSync();
      await pumpEventQueue();
      sheet.appendGate!.complete();
      await Future.wait([running, full]);

      expect(sheet.transactions.countOf(expense.id), 1);
    });
  });

  group('pushing a change', () {
    setUp(seedSheetWithDefaults);

    test('an expense edited before its first push still reaches the sheet',
        () async {
      engine.online = false;
      final expense = await recordExpense(amount: 10);
      await transactions.update(expense.copyWith(amount: 20));

      engine.online = true;
      await engine.sync();

      expect(sheet.transactions.countOf(expense.id), 1);
      expect(sheet.transactions.byId(expense.id)!.amount, 20);
    });

    test('a failed row lookup is retried, not treated as a missing row',
        () async {
      final expense = await recordExpense(amount: 10);
      await engine.sync();
      await transactions.update(expense.copyWith(amount: 20));

      sheet.failLookups = true;
      await engine.sync();

      expect(await queuedCount(), 1, reason: 'the edit stays queued');
      expect(sheet.transactions.byId(expense.id)!.amount, 10);

      sheet.failLookups = false;
      await engine.sync();

      expect(sheet.transactions.countOf(expense.id), 1);
      expect(sheet.transactions.byId(expense.id)!.amount, 20);
    });

    test('an edit made while the create is being pushed is pushed next',
        () async {
      final expense = await recordExpense(amount: 10);
      var edited = false;
      sheet.onAppend = () async {
        if (edited) return;
        edited = true;
        await transactions.update(expense.copyWith(amount: 20));
      };

      await engine.sync();
      expect(await queuedCount(), 1, reason: 'the edit is still queued');

      await engine.sync();
      expect(sheet.transactions.countOf(expense.id), 1);
      expect(sheet.transactions.byId(expense.id)!.amount, 20);
    });
  });

  group('built-in categories and accounts', () {
    test('a fresh database uses the shared built-in IDs', () async {
      final categoryIds = {for (final c in await categoryDao.getAll()) c.id};
      final accountIds = {for (final a in await accountDao.getAll()) a.id};

      expect(categoryIds, {
        for (final d in CategoryDefaults.expenseCategories) d.id,
        for (final d in CategoryDefaults.incomeCategories) d.id,
      });
      expect(accountIds, {
        for (final d in CategoryDefaults.defaultAccounts) d.id,
      });
    });

    test('sync uploads the built-ins an old spreadsheet lacks, if used',
        () async {
      seedSheetLikeOldVersion();
      await recordExpense(categoryId: 'cat_food', accountId: 'acc_cash');

      await engine.sync();

      expect(sheet.categories.countOf('cat_food'), 1);
      expect(sheet.accounts.countOf('acc_cash'), 1);
      expect(sheet.categories.byId('cat_grocery'), isNull,
          reason: 'unused built-ins are not uploaded');
      expect(await queuedCount(), 0);
    });

    test('full sync brings back built-ins an earlier full sync removed',
        () async {
      seedSheetLikeOldVersion();
      // An earlier version pushed this expense but never the built-in
      // category and account it uses...
      final now = DateTime(2026, 10, 1);
      sheet.transactions.rows.add(Transaction(
        id: 'pushed-by-old-version',
        date: now,
        amount: 30,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        createdAt: now,
        updatedAt: now,
      ));
      // ...and its full sync then deleted them on this device.
      await categoryDao.delete('cat_food');
      await accountDao.delete('acc_cash');

      await engine.fullSync();

      final food = await categoryDao.getById('cat_food');
      expect(food?.name, 'Food & Dining');
      expect((await accountDao.getById('acc_cash'))?.name, 'Cash');
      expect(sheet.categories.countOf('cat_food'), 1);
      expect(sheet.accounts.countOf('acc_cash'), 1);
      expect(await transactionDao.getById('pushed-by-old-version'), isNotNull);
    });

    test('full sync keeps local edits to a built-in the sheet lacks', () async {
      seedSheetLikeOldVersion();
      final cash = await accountDao.getById('acc_cash');
      await accountDao.update(cash!.copyWith(initialBalance: 500));
      await recordExpense(accountId: 'acc_cash');

      await engine.fullSync();

      expect((await accountDao.getById('acc_cash'))?.initialBalance, 500);
      expect(sheet.accounts.byId('acc_cash')?.initialBalance, 500);
    });

    test('user-made categories missing from the sheet are left alone',
        () async {
      seedSheetLikeOldVersion();
      await recordExpense(categoryId: 'deleted-on-sheet');

      await engine.fullSync();

      expect(await categoryDao.getById('deleted-on-sheet'), isNull);
      expect(sheet.categories.byId('deleted-on-sheet'), isNull);
    });
  });
}
