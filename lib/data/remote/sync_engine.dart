import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/category_defaults.dart';
import '../../core/constants/sheet_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/person.dart';
import '../models/loan.dart';
import '../models/app_settings.dart';
import '../local/local_transaction_dao.dart';
import '../local/local_category_dao.dart';
import '../local/local_account_dao.dart';
import '../local/local_budget_dao.dart';
import '../local/local_person_dao.dart';
import '../local/local_loan_dao.dart';
import '../local/sync_queue_dao.dart';
import 'sheets_service.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  pending,
  error,
}

/// Everything read from the spreadsheet in one pass. A list is null when
/// reading that tab failed, so callers leave that data alone.
class _RemoteData {
  final List<Transaction>? transactions;
  final List<Category>? categories;
  final List<Account>? accounts;
  final List<Budget>? budgets;
  final List<Person>? people;
  final List<Loan>? loans;

  const _RemoteData({
    required this.transactions,
    required this.categories,
    required this.accounts,
    required this.budgets,
    required this.people,
    required this.loans,
  });

  bool get isComplete =>
      transactions != null &&
      categories != null &&
      accounts != null &&
      budgets != null &&
      people != null &&
      loans != null;
}

class SyncEngine {
  static const List<String> _entityTypes = [
    'transaction',
    'category',
    'account',
    'budget',
    'person',
    'loan',
  ];

  final SheetsService _sheetsService;
  final LocalTransactionDao _transactionDao;
  final LocalCategoryDao _categoryDao;
  final LocalAccountDao _accountDao;
  final LocalBudgetDao _budgetDao;
  final LocalPersonDao _personDao;
  final LocalLoanDao _loanDao;
  final SyncQueueDao _syncQueueDao;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  Timer? _syncTimer;
  Timer? _batchTimer;
  bool _isSyncing = false;
  Completer<void>? _inFlight;
  String? _spreadsheetId;

  final List<Map<String, dynamic>> _pendingBatch = [];

  SyncEngine({
    required SheetsService sheetsService,
    required LocalTransactionDao transactionDao,
    required LocalCategoryDao categoryDao,
    required LocalAccountDao accountDao,
    required LocalBudgetDao budgetDao,
    required LocalPersonDao personDao,
    required LocalLoanDao loanDao,
    required SyncQueueDao syncQueueDao,
  })  : _sheetsService = sheetsService,
        _transactionDao = transactionDao,
        _categoryDao = categoryDao,
        _accountDao = accountDao,
        _budgetDao = budgetDao,
        _personDao = personDao,
        _loanDao = loanDao,
        _syncQueueDao = syncQueueDao;

  Future<void> initialize(String spreadsheetId) async {
    _spreadsheetId = spreadsheetId;

    // Ensure People/Loans sheets exist (handles pre-loans spreadsheets)
    // Use a timeout so this never blocks app startup
    try {
      await _sheetsService.ensureSheetsExist(spreadsheetId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('SyncEngine: ensureSheetsExist timed out, will retry next sync');
        },
      );
    } catch (e) {
      debugPrint('SyncEngine: ensureSheetsExist failed (will retry next sync): $e');
    }

    // Changes that ran out of retries in an earlier session get another
    // chance. They stay queued until they reach the sheet.
    final resetCount = await _syncQueueDao.resetFailedItems(_entityTypes);
    if (resetCount > 0) {
      debugPrint('SyncEngine: reset $resetCount failed sync items');
    }

    await _checkPendingSync();
    _startPeriodicSync();
  }

  /// Stops syncing and forgets the spreadsheet, after letting a sync that is
  /// already running finish. Called when the account signs out or changes,
  /// so nothing more is written to that account's spreadsheet.
  Future<void> stop() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    await _waitForInFlightSync();
    _spreadsheetId = null;
    _pendingBatch.clear();
    _updateStatus(SyncStatus.idle);
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      AppConstants.syncInterval,
      (_) => sync(),
    );
  }

  Future<void> _checkPendingSync() async {
    final pendingCount = await _syncQueueDao.getPendingCount();
    if (pendingCount > 0) {
      _updateStatus(SyncStatus.pending);
    } else {
      _updateStatus(SyncStatus.synced);
    }
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<bool> isOnline() async {
    // One entry per active connection type; [none] alone means offline.
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  static const String _lastSyncKey = 'settings_last_sync_at';

  Future<void> sync() async {
    if (_spreadsheetId == null) return;
    if (_isSyncing) {
      _scheduleBatchSync(); // retry in 5 seconds
      return;
    }

    _beginSync();
    try {
      final online = await isOnline();
      if (!online) {
        _updateStatus(SyncStatus.pending);
        return;
      }

      _updateStatus(SyncStatus.syncing);

      // Push pending changes first
      await _pushPendingChanges();

      // Then pull remote changes
      final remote = await _pullAll();
      final restored = await _restoreMissingDefaults(remote);
      await _applyRemote(remote, replace: false);
      if (restored > 0) await _pushPendingChanges();

      // Only update last sync time if all pulls succeeded
      if (remote.isComplete) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      }

      _updateStatus(SyncStatus.synced);
    } catch (e, stackTrace) {
      debugPrint('Sync failed: $e');
      debugPrint('Sync stack trace: $stackTrace');
      _updateStatus(SyncStatus.error);
    } finally {
      _endSync();
    }
  }

  /// Rebuilds local data from the spreadsheet.
  ///
  /// Queued local changes are pushed first. An entity whose change still
  /// cannot be pushed keeps its local copy and its queue entry, so a full
  /// sync never throws away work that has not reached the sheet yet.
  Future<void> fullSync() async {
    if (_spreadsheetId == null) return;

    // Never overlap an incremental sync: both would push the same items.
    await _waitForInFlightSync();
    _beginSync();
    try {
      if (!await isOnline()) throw SyncException.noConnection();
    } catch (_) {
      _endSync();
      rethrow;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // Retry everything, including changes that ran out of retries before.
      await _syncQueueDao.resetFailedItems(_entityTypes);
      await _pushPendingChanges();

      final remote = await _pullAll();
      final restored = await _restoreMissingDefaults(remote);
      await _applyRemote(remote, replace: true);
      if (restored > 0) await _pushPendingChanges();

      // Only set last_sync_at if ALL pulls succeeded — so next startup retries
      if (remote.isComplete) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      }

      // Changes that still failed stay queued, so report them as pending.
      await _checkPendingSync();
    } catch (e) {
      debugPrint('Full sync failed: $e');
      _updateStatus(SyncStatus.error);
      rethrow;
    } finally {
      _endSync();
    }
  }

  void _beginSync() {
    _isSyncing = true;
    _inFlight = Completer<void>();
  }

  void _endSync() {
    _isSyncing = false;
    final done = _inFlight;
    _inFlight = null;
    done?.complete();
  }

  Future<void> _waitForInFlightSync() async {
    while (_inFlight != null) {
      await _inFlight!.future;
    }
  }

  /// Retries a pull operation once on failure with a 2-second delay.
  /// Returns null if both attempts fail.
  Future<List<T>?> _pullWithRetry<T>(
    Future<List<T>> Function() pullFn,
    String entityName,
  ) async {
    try {
      return await pullFn();
    } catch (e) {
      debugPrint('Pull $entityName failed, retrying in 2s: $e');
      await Future.delayed(const Duration(seconds: 2));
      try {
        return await pullFn();
      } catch (e2, st) {
        debugPrint('Pull $entityName retry failed: $e2');
        debugPrint('$st');
        return null;
      }
    }
  }

  Future<void> _pushPendingChanges() async {
    final pendingItems = await _syncQueueDao.getPending();
    if (pendingItems.isEmpty) return;

    debugPrint('SyncEngine: pushing ${pendingItems.length} pending items');

    for (final item in pendingItems) {
      try {
        await _processSyncItem(item);
        await _syncQueueDao.deleteIfUnchanged(item);
        debugPrint('SyncEngine: synced ${item.entityType} ${item.operation} (${item.entityId})');
      } catch (e) {
        debugPrint('SyncEngine: failed to sync ${item.entityType} ${item.operation} '
            '(${item.entityId}, retry ${item.retryCount + 1}/3): $e');
        await _syncQueueDao.incrementRetryCount(
          item.id,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _processSyncItem(SyncQueueItem item) async {
    final data = jsonDecode(item.data) as Map<String, dynamic>;
    final sheetId = _spreadsheetId!;
    final op = item.operation;

    switch (item.entityType) {
      case 'transaction':
        final transaction = Transaction.fromJson(data);
        await _pushRow(
          operation: op,
          sheetName: SheetConstants.transactionsSheet,
          id: transaction.id,
          append: () => _sheetsService.appendTransaction(sheetId, transaction),
          update: (row) =>
              _sheetsService.updateTransaction(sheetId, transaction, row),
        );
      case 'category':
        final category = Category.fromJson(data);
        await _pushRow(
          operation: op,
          sheetName: SheetConstants.categoriesSheet,
          id: category.id,
          append: () => _sheetsService.appendCategory(sheetId, category),
          update: (row) =>
              _sheetsService.updateCategory(sheetId, category, row),
        );
      case 'account':
        final account = Account.fromJson(data);
        await _pushRow(
          operation: op,
          sheetName: SheetConstants.accountsSheet,
          id: account.id,
          append: () => _sheetsService.appendAccount(sheetId, account),
          update: (row) => _sheetsService.updateAccount(sheetId, account, row),
        );
      case 'budget':
        final budget = Budget.fromJson(data);
        await _pushRow(
          operation: op,
          sheetName: SheetConstants.budgetsSheet,
          id: budget.id,
          append: () => _sheetsService.appendBudget(sheetId, budget),
          update: (row) => _sheetsService.updateBudget(sheetId, budget, row),
        );
      case 'person':
        final person = Person.fromJson(data);
        await _pushRow(
          operation: op,
          sheetName: SheetConstants.peopleSheet,
          id: person.id,
          append: () => _sheetsService.appendPerson(sheetId, person),
          update: (row) => _sheetsService.updatePerson(sheetId, person, row),
        );
      case 'loan':
        final loan = Loan.fromJson(data);
        await _pushRow(
          operation: op,
          sheetName: SheetConstants.loansSheet,
          id: loan.id,
          append: () => _sheetsService.appendLoan(sheetId, loan),
          update: (row) => _sheetsService.updateLoan(sheetId, loan, row),
        );
    }
  }

  /// Pushes one queued change to [sheetName].
  ///
  /// The queue keeps one entry per entity, so an entity that was created and
  /// then edited before its create was pushed arrives as an 'update' for a
  /// row the sheet does not have yet. That row is appended, not dropped.
  Future<void> _pushRow({
    required String operation,
    required String sheetName,
    required String id,
    required Future<void> Function() append,
    required Future<void> Function(int rowIndex) update,
  }) async {
    if (operation == 'create') {
      await append();
      return;
    }

    final rowIndex = await _sheetsService.findRowByIdInSheet(
      _spreadsheetId!,
      sheetName,
      id,
    );
    if (rowIndex > 0) {
      await update(rowIndex);
    } else if (operation == 'update') {
      await append();
    }
    // A delete of a row that never reached the sheet has nothing to do.
  }

  Future<_RemoteData> _pullAll() async {
    final id = _spreadsheetId!;
    return _RemoteData(
      transactions: await _pullWithRetry(
          () => _sheetsService.getAllTransactions(id), 'transactions'),
      categories: await _pullWithRetry(
          () => _sheetsService.getAllCategories(id), 'categories'),
      accounts: await _pullWithRetry(
          () => _sheetsService.getAllAccounts(id), 'accounts'),
      budgets: await _pullWithRetry(
          () => _sheetsService.getAllBudgets(id), 'budgets'),
      people:
          await _pullWithRetry(() => _sheetsService.getAllPeople(id), 'people'),
      loans:
          await _pullWithRetry(() => _sheetsService.getAllLoans(id), 'loans'),
    );
  }

  /// IDs of entities with a change still in the queue, by entity type,
  /// including changes that have used up their retries.
  Future<Map<String, Set<String>>> _queuedIdsByType() async {
    final ids = <String, Set<String>>{};
    for (final item in await _syncQueueDao.getAll()) {
      ids.putIfAbsent(item.entityType, () => <String>{}).add(item.entityId);
    }
    return ids;
  }

  /// Writes pulled rows into the local database.
  ///
  /// With [replace], local rows the sheet no longer has are removed as well.
  /// Either way, an entity with a queued change keeps its local copy, so a
  /// pull never overwrites or deletes a change that has not been pushed.
  Future<void> _applyRemote(_RemoteData remote, {required bool replace}) async {
    final queued = await _queuedIdsByType();

    Future<void> apply<T>(
      String type,
      List<T>? rows,
      String Function(T) idOf,
      Future<int> Function({Set<String> except}) deleteAll,
      Future<int> Function(List<T>) insertBatch,
    ) async {
      if (rows == null) return; // this tab failed to download
      final keep = queued[type] ?? const <String>{};
      if (replace) await deleteAll(except: keep);
      final fresh = rows.where((row) => !keep.contains(idOf(row))).toList();
      if (fresh.isNotEmpty) await insertBatch(fresh);
      debugPrint('Pulled ${fresh.length} $type rows from sheet'
          ' (${rows.length - fresh.length} skipped, local change pending)');
    }

    await apply<Transaction>('transaction', remote.transactions, (t) => t.id,
        _transactionDao.deleteAll, _transactionDao.insertBatch);
    await apply<Category>('category', remote.categories, (c) => c.id,
        _categoryDao.deleteAll, _categoryDao.insertBatch);
    await apply<Account>('account', remote.accounts, (a) => a.id,
        _accountDao.deleteAll, _accountDao.insertBatch);
    await apply<Budget>('budget', remote.budgets, (b) => b.id,
        _budgetDao.deleteAll, _budgetDao.insertBatch);
    await apply<Person>('person', remote.people, (p) => p.id,
        _personDao.deleteAll, _personDao.insertBatch);
    await apply<Loan>('loan', remote.loans, (l) => l.id, _loanDao.deleteAll,
        _loanDao.insertBatch);
  }

  /// Queues built-in categories and accounts that data uses but the sheet
  /// lacks, and returns how many were queued.
  ///
  /// Spreadsheets created by earlier versions gave the built-in categories and
  /// accounts random IDs, while the local database uses fixed ones (cat_food,
  /// acc_cash, ...). Transactions recorded against the local rows pointed at
  /// rows the sheet never had, and a full sync then orphaned them. Each such
  /// row is uploaded from its local copy, or rebuilt from the defaults when
  /// the local copy is already gone.
  Future<int> _restoreMissingDefaults(_RemoteData remote) async {
    final queued = await _queuedIdsByType();
    final now = DateTime.now();
    var restored = 0;

    final remoteCategories = remote.categories;
    if (remoteCategories != null) {
      final onSheet = {for (final c in remoteCategories) c.id};
      final used = {
        ...await _transactionDao.getUsedCategoryIds(),
        ...await _budgetDao.getUsedCategoryIds(),
        ...?remote.transactions
            ?.where((t) => !t.isDeleted)
            .map((t) => t.categoryId),
        ...?remote.budgets
            ?.where((b) => !b.isDeleted && b.categoryId != null)
            .map((b) => b.categoryId!),
      };
      for (final id in used) {
        if (onSheet.contains(id) ||
            (queued['category']?.contains(id) ?? false)) {
          continue;
        }
        final builtIn = _builtInCategory(id, now);
        if (builtIn == null) continue; // only built-ins can be restored
        var category = await _categoryDao.getById(id);
        if (category == null) {
          category = builtIn;
          await _categoryDao.insert(category);
        }
        await _syncQueueDao.enqueue(
          entityType: 'category',
          entityId: id,
          operation: 'create',
          data: category.toJson(),
        );
        restored++;
      }
    }

    final remoteAccounts = remote.accounts;
    if (remoteAccounts != null) {
      final onSheet = {for (final a in remoteAccounts) a.id};
      final used = {
        ...await _transactionDao.getUsedAccountIds(),
        ...?remote.transactions?.where((t) => !t.isDeleted).expand(
            (t) => [t.accountId, if (t.toAccountId != null) t.toAccountId!]),
      };
      for (final id in used) {
        if (onSheet.contains(id) ||
            (queued['account']?.contains(id) ?? false)) {
          continue;
        }
        final builtIn = _builtInAccount(id, now);
        if (builtIn == null) continue; // only built-ins can be restored
        var account = await _accountDao.getById(id);
        if (account == null) {
          account = builtIn;
          await _accountDao.insert(account);
        }
        await _syncQueueDao.enqueue(
          entityType: 'account',
          entityId: id,
          operation: 'create',
          data: account.toJson(),
        );
        restored++;
      }
    }

    if (restored > 0) {
      debugPrint(
          'SyncEngine: queued $restored built-in rows missing from sheet');
    }
    return restored;
  }

  static Category? _builtInCategory(String id, DateTime now) {
    for (final (type, defaults) in [
      (CategoryType.expense, CategoryDefaults.expenseCategories),
      (CategoryType.income, CategoryDefaults.incomeCategories),
    ]) {
      for (var i = 0; i < defaults.length; i++) {
        final d = defaults[i];
        if (d.id != id) continue;
        return Category(
          id: d.id,
          name: d.name,
          type: type,
          icon: d.icon,
          color: d.color,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        );
      }
    }
    return null;
  }

  static Account? _builtInAccount(String id, DateTime now) {
    const defaults = CategoryDefaults.defaultAccounts;
    for (var i = 0; i < defaults.length; i++) {
      final d = defaults[i];
      if (d.id != id) continue;
      return Account(
        id: d.id,
        name: d.name,
        type: AccountType.values.byName(d.type),
        initialBalance: 0,
        currency: 'USD',
        icon: d.icon,
        color: d.color,
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      );
    }
    return null;
  }

  // Queue operations for batch processing
  Future<void> queueOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    await _syncQueueDao.enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      data: data,
    );

    _updateStatus(SyncStatus.pending);
    _scheduleBatchSync();
  }

  void _scheduleBatchSync() {
    _batchTimer?.cancel();
    _batchTimer = Timer(
      AppConstants.batchWriteDelay,
      () => sync(),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }

  Future<int> getPendingCount() async {
    return await _syncQueueDao.getPendingCount();
  }

  void dispose() {
    _syncTimer?.cancel();
    _batchTimer?.cancel();
    _statusController.close();
  }
}
