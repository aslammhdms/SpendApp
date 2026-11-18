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

/// A sheet that stores the first appended transaction but reports a failure,
/// like a write whose reply was lost on the way back.
class _LostReplySheet extends FakeSheetsService {
  bool loseNextReply = true;

  @override
  Future<void> appendTransaction(String spreadsheetId, Transaction t) async {
    await super.appendTransaction(spreadsheetId, t);
    if (loseNextReply) {
      loseNextReply = false;
      throw Exception('reply lost');
    }
  }
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

  group('stopping (sign-out or a change of account)', () {
    setUp(seedSheetWithDefaults);

    test('nothing reaches the spreadsheet after stop', () async {
      engine.online = false;
      final expense = await recordExpense();
      engine.online = true;

      await engine.stop();
      await engine.sync();
      await engine.fullSync();

      expect(sheet.transactions.countOf(expense.id), 0);
      expect(await queuedCount(), 1, reason: 'the change stays queued');
    });

    test('lets a push that is already running finish first', () async {
      final expense = await recordExpense();
      sheet.appendGate = Completer<void>();

      final running = engine.sync(); // blocks inside the append
      await pumpEventQueue();
      var stopped = false;
      final stopping = engine.stop().then((_) => stopped = true);
      await pumpEventQueue();
      expect(stopped, isFalse);

      sheet.appendGate!.complete();
      await Future.wait([running, stopping]);

      expect(sheet.transactions.countOf(expense.id), 1);
      expect(await queuedCount(), 0);
    });

    test('syncing resumes when the engine is initialized again', () async {
      engine.online = false;
      final expense = await recordExpense();
      engine.online = true;
      await engine.stop();

      await engine.initialize('sheet-1');
      await engine.sync();

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

    test('sync uploads a used built-in when the sheet has nothing like it',
        () async {
      seedSheetLikeOldVersion();
      // This old spreadsheet has no "Food & Dining" and no "Cash".
      sheet.categories.rows.removeWhere((c) => c.id == 'old-cat_food');
      sheet.accounts.rows.removeWhere((a) => a.id == 'old-acc_cash');
      await recordExpense(categoryId: 'cat_food', accountId: 'acc_cash');

      await engine.sync();

      expect(sheet.categories.countOf('cat_food'), 1);
      expect(sheet.accounts.countOf('acc_cash'), 1);
      expect(sheet.categories.byId('cat_grocery'), isNull,
          reason: 'unused built-ins are not uploaded');
      expect(await queuedCount(), 0);
    });

    test('full sync brings back a built-in an earlier full sync removed',
        () async {
      seedSheetLikeOldVersion();
      sheet.categories.rows.removeWhere((c) => c.id == 'old-cat_food');
      sheet.accounts.rows.removeWhere((a) => a.id == 'old-acc_cash');
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

  group('a built-in and an old spreadsheet row with the same name', () {
    Future<List<String>> liveCategoryNames() async =>
        [for (final c in await categoryDao.getAll()) c.name]..sort();

    test('an expense on the built-in moves to the spreadsheet\'s row',
        () async {
      seedSheetLikeOldVersion();
      final expense =
          await recordExpense(categoryId: 'cat_food', accountId: 'acc_cash');

      await engine.sync();

      final local = await transactionDao.getById(expense.id);
      expect(local?.categoryId, 'old-cat_food');
      expect(local?.accountId, 'old-acc_cash');
      expect(sheet.transactions.byId(expense.id)?.categoryId, 'old-cat_food');
      expect(sheet.transactions.byId(expense.id)?.accountId, 'old-acc_cash');
      expect(sheet.categories.byId('cat_food'), isNull,
          reason: 'no second "Food & Dining" is uploaded');
      expect(sheet.accounts.byId('acc_cash'), isNull);
      expect(await queuedCount(), 0);
    });

    test('each name is listed once afterwards', () async {
      seedSheetLikeOldVersion();
      await recordExpense(categoryId: 'cat_food', accountId: 'acc_cash');

      await engine.sync();

      final names = await liveCategoryNames();
      expect(names.where((n) => n == 'Food & Dining'), hasLength(1));
      // "Investments" exists once as an expense and once as an income
      // category, so compare within a type.
      final typed = [
        for (final c in await categoryDao.getAll()) '${c.type.name}/${c.name}',
      ];
      expect(typed.toSet().length, typed.length, reason: 'no name repeats');
      final accounts = [for (final a in await accountDao.getAll()) a.name];
      expect(accounts.where((n) => n == 'Cash'), hasLength(1));
    });

    test('a duplicate already on the spreadsheet is removed there too',
        () async {
      seedSheetLikeOldVersion();
      // An earlier version of this fix uploaded the built-in next to the
      // spreadsheet's own row, with an expense on each.
      final now = DateTime(2026, 11, 1);
      sheet.categories.rows.add((await categoryDao.getById('cat_food'))!);
      for (final (id, category) in [
        ('on-built-in', 'cat_food'),
        ('on-old-row', 'old-cat_food'),
      ]) {
        sheet.transactions.rows.add(Transaction(
          id: id,
          date: now,
          amount: 10,
          type: TransactionType.expense,
          categoryId: category,
          accountId: 'old-acc_cash',
          createdAt: now,
          updatedAt: now,
        ));
      }

      await engine.fullSync();

      expect(sheet.categories.byId('cat_food')?.isDeleted, isTrue);
      expect(sheet.categories.byId('old-cat_food')?.isDeleted, isFalse);
      expect(sheet.transactions.byId('on-built-in')?.categoryId,
          'old-cat_food');
      expect(sheet.transactions.byId('on-old-row')?.categoryId,
          'old-cat_food');
      final names = await liveCategoryNames();
      expect(names.where((n) => n == 'Food & Dining'), hasLength(1));
      expect(await queuedCount(), 0);

      // And it stays that way.
      await engine.fullSync();
      expect((await liveCategoryNames()).where((n) => n == 'Food & Dining'),
          hasLength(1));
      expect(sheet.categories.countOf('cat_food'), 1);
    });

    test('a transfer between two built-in accounts moves both ends',
        () async {
      seedSheetLikeOldVersion();
      final transfer = await transactions.create(
        amount: 40,
        type: TransactionType.transfer,
        categoryId: '',
        accountId: 'acc_cash',
        toAccountId: 'acc_bank',
      );

      await engine.sync();

      final local = await transactionDao.getById(transfer.id);
      expect(local?.accountId, 'old-acc_cash');
      expect(local?.toAccountId, 'old-acc_bank');
    });

    test('a built-in the spreadsheet\'s copy was deleted from is kept',
        () async {
      seedSheetLikeOldVersion();
      final i = sheet.categories.rows.indexWhere((c) => c.id == 'old-cat_food');
      sheet.categories.rows[i] = sheet.categories.rows[i].copyWithDelete();
      final expense = await recordExpense(categoryId: 'cat_food');

      await engine.sync();

      expect((await transactionDao.getById(expense.id))?.categoryId,
          'cat_food');
      expect(sheet.categories.byId('cat_food')?.isDeleted, isFalse);
    });

    test('a renamed copy is not treated as the same category', () async {
      seedSheetLikeOldVersion();
      final i = sheet.categories.rows.indexWhere((c) => c.id == 'old-cat_food');
      sheet.categories.rows[i] =
          sheet.categories.rows[i].copyWith(name: 'Eating out');
      final expense = await recordExpense(categoryId: 'cat_food');

      await engine.sync();

      expect((await transactionDao.getById(expense.id))?.categoryId,
          'cat_food');
    });

    test('two categories the user made with one name are left alone',
        () async {
      await seedSheetWithDefaults();
      final now = DateTime(2026, 11, 1);
      for (final id in ['mine-1', 'mine-2']) {
        sheet.categories.rows.add(Category(
          id: id,
          name: 'Coffee',
          type: CategoryType.expense,
          icon: '☕',
          color: 0xFF795548,
          sortOrder: 50,
          createdAt: now,
          updatedAt: now,
        ));
      }

      await engine.fullSync();

      final names = await liveCategoryNames();
      expect(names.where((n) => n == 'Coffee'), hasLength(2));
    });

    test('a spreadsheet made by this version is left as it is', () async {
      await seedSheetWithDefaults();
      final expense = await recordExpense(categoryId: 'cat_food');

      await engine.sync();

      expect((await transactionDao.getById(expense.id))?.categoryId,
          'cat_food');
      expect(sheet.categories.byId('cat_food')?.isDeleted, isFalse);
      expect(await queuedCount(), 0);
    });
  });

  group('rows the app cannot rely on', () {
    Transaction row(String id, double amount) {
      final now = DateTime(2026, 11, 1);
      return Transaction(
        id: id,
        date: now,
        amount: amount,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('a cell that is not a number does not break the sync', () async {
      await seedSheetWithDefaults();
      sheet.transactions.rows.addAll([row('good-1', 10), row('good-2', 20)]);
      await engine.fullSync();

      // Someone types NaN into an amount cell and adds another row.
      sheet.transactions.rows.add(Transaction.fromSheetRow(
          ['bad', '2026-11-01T00:00:00.000', 'NaN', 'expense', 'cat_food', 'acc_cash']));
      sheet.transactions.rows.add(row('good-3', 30));

      await engine.fullSync();

      expect(await transactionDao.getById('good-1'), isNotNull);
      expect(await transactionDao.getById('good-2'), isNotNull);
      expect(await transactionDao.getById('good-3'), isNotNull);
      expect(await transactionDao.getById('bad'), isNull);
    });

    test('a broken cell keeps the local copy of that row', () async {
      await seedSheetWithDefaults();
      sheet.transactions.rows.add(row('kept', 10));
      await engine.fullSync();

      sheet.transactions.rows[0] = row('kept', double.nan);
      await engine.fullSync();

      expect((await transactionDao.getById('kept'))?.amount, 10);
    });

    test('a row without an id is ignored', () async {
      await seedSheetWithDefaults();
      sheet.transactions.rows.addAll([row('', 5), row('real', 7)]);

      await engine.fullSync();

      expect(await transactionDao.getById(''), isNull);
      expect(await transactionDao.getById('real'), isNotNull);
    });

    test('of two rows with one id the first one wins', () async {
      await seedSheetWithDefaults();
      sheet.transactions.rows.addAll([row('twice', 99), row('twice', 10)]);

      await engine.fullSync();

      expect((await transactionDao.getById('twice'))?.amount, 99);
    });
  });

  group('a create whose reply was lost', () {
    test('is not appended a second time, and later changes stick', () async {
      final lossy = _LostReplySheet();
      final lossyEngine = _TestSyncEngine(
        sheetsService: lossy,
        transactionDao: transactionDao,
        categoryDao: categoryDao,
        accountDao: accountDao,
        budgetDao: LocalBudgetDao(),
        personDao: LocalPersonDao(),
        loanDao: LocalLoanDao(),
        syncQueueDao: queueDao,
      );
      addTearDown(lossyEngine.dispose);
      final repo = TransactionRepository(
        localDao: transactionDao,
        syncQueueDao: queueDao,
        syncEngine: lossyEngine,
      );
      await lossyEngine.initialize('sheet-1');
      lossy.categories.rows.addAll(await categoryDao.getAll());
      lossy.accounts.rows.addAll(await accountDao.getAll());

      final created = await repo.create(
        date: DateTime(2026, 11, 1),
        amount: 25,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
      );
      await lossyEngine.sync(); // stored, but reported as failed
      await lossyEngine.sync(); // the retry

      expect(lossy.transactions.rows.where((t) => t.id == created.id), hasLength(1));

      await repo.update(created.copyWith(amount: 70));
      await lossyEngine.sync();

      expect((await transactionDao.getById(created.id))?.amount, 70);
    });
  });
}
