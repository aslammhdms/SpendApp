import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
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

class SyncEngine {
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
      // Reset any previously-failed person/loan sync items so they get retried
      final resetCount = await _syncQueueDao.resetFailedItems(['person', 'loan']);
      if (resetCount > 0) {
        debugPrint('SyncEngine: reset $resetCount failed person/loan sync items');
      }
    } catch (e) {
      debugPrint('SyncEngine: ensureSheetsExist failed (will retry next sync): $e');
    }

    await _checkPendingSync();
    _startPeriodicSync();
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
    final result = await Connectivity().checkConnectivity();
    // connectivity_plus 5.x returns List<ConnectivityResult>
    if (result is List) {
      return !(result as List).contains(ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  static const String _lastSyncKey = 'settings_last_sync_at';

  Future<void> sync() async {
    if (_spreadsheetId == null) return;
    if (_isSyncing) {
      _scheduleBatchSync(); // retry in 5 seconds
      return;
    }

    final online = await isOnline();
    if (!online) {
      _updateStatus(SyncStatus.pending);
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      // Push pending changes first
      await _pushPendingChanges();

      // Then pull remote changes
      final allPulled = await _pullRemoteChanges();

      // Only update last sync time if all pulls succeeded
      if (allPulled) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      }

      _updateStatus(SyncStatus.synced);
    } catch (e, stackTrace) {
      debugPrint('Sync failed: $e');
      debugPrint('Sync stack trace: $stackTrace');
      _updateStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> fullSync() async {
    if (_spreadsheetId == null) return;

    final online = await isOnline();
    if (!online) {
      throw SyncException.noConnection();
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      // Pull all data into memory FIRST — before clearing anything
      List<Transaction>? transactions;
      List<Category>? categories;
      List<Account>? accounts;
      List<Budget>? budgets;
      List<Person>? people;
      List<Loan>? loans;
      bool allSucceeded = true;

      transactions = await _pullWithRetry(
        () => _sheetsService.getAllTransactions(_spreadsheetId!),
        'transactions',
      );
      if (transactions == null) allSucceeded = false;

      categories = await _pullWithRetry(
        () => _sheetsService.getAllCategories(_spreadsheetId!),
        'categories',
      );
      if (categories == null) allSucceeded = false;

      accounts = await _pullWithRetry(
        () => _sheetsService.getAllAccounts(_spreadsheetId!),
        'accounts',
      );
      if (accounts == null) allSucceeded = false;

      budgets = await _pullWithRetry(
        () => _sheetsService.getAllBudgets(_spreadsheetId!),
        'budgets',
      );
      if (budgets == null) allSucceeded = false;

      people = await _pullWithRetry(
        () => _sheetsService.getAllPeople(_spreadsheetId!),
        'people',
      );
      if (people == null) allSucceeded = false;

      loans = await _pullWithRetry(
        () => _sheetsService.getAllLoans(_spreadsheetId!),
        'loans',
      );
      if (loans == null) allSucceeded = false;

      // Now clear + insert only for entities that pulled successfully
      if (transactions != null) {
        await _transactionDao.deleteAll();
        if (transactions.isNotEmpty) await _transactionDao.insertBatch(transactions);
      }
      if (categories != null) {
        await _categoryDao.deleteAll();
        if (categories.isNotEmpty) await _categoryDao.insertBatch(categories);
      }
      if (accounts != null) {
        await _accountDao.deleteAll();
        if (accounts.isNotEmpty) await _accountDao.insertBatch(accounts);
      }
      if (budgets != null) {
        await _budgetDao.deleteAll();
        if (budgets.isNotEmpty) await _budgetDao.insertBatch(budgets);
      }
      if (people != null) {
        await _personDao.deleteAll();
        if (people.isNotEmpty) await _personDao.insertBatch(people);
      }
      if (loans != null) {
        await _loanDao.deleteAll();
        if (loans.isNotEmpty) await _loanDao.insertBatch(loans);
      }

      // Clear sync queue regardless
      await _syncQueueDao.deleteAll();

      // Only set last_sync_at if ALL pulls succeeded — so next startup retries
      if (allSucceeded) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      }

      _updateStatus(SyncStatus.synced);
    } catch (e) {
      debugPrint('Full sync failed: $e');
      _updateStatus(SyncStatus.error);
      rethrow;
    } finally {
      _isSyncing = false;
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
        await _syncQueueDao.delete(item.id);
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

    switch (item.entityType) {
      case 'transaction':
        await _syncTransaction(item.operation, data);
        break;
      case 'category':
        await _syncCategory(item.operation, data);
        break;
      case 'account':
        await _syncAccount(item.operation, data);
        break;
      case 'budget':
        await _syncBudget(item.operation, data);
        break;
      case 'person':
        await _syncPerson(item.operation, data);
        break;
      case 'loan':
        await _syncLoan(item.operation, data);
        break;
    }
  }

  Future<void> _syncTransaction(String operation, Map<String, dynamic> data) async {
    final transaction = Transaction.fromJson(data);

    switch (operation) {
      case 'create':
        await _sheetsService.appendTransaction(_spreadsheetId!, transaction);
        break;
      case 'update':
      case 'delete':
        final rowIndex = await _sheetsService.findRowByIdInSheet(
          _spreadsheetId!,
          'Transactions',
          transaction.id,
        );
        if (rowIndex > 0) {
          await _sheetsService.updateTransaction(
            _spreadsheetId!,
            transaction,
            rowIndex,
          );
        }
        break;
    }
  }

  Future<void> _syncCategory(String operation, Map<String, dynamic> data) async {
    final category = Category.fromJson(data);

    switch (operation) {
      case 'create':
        await _sheetsService.appendCategory(_spreadsheetId!, category);
        break;
      case 'update':
      case 'delete':
        final rowIndex = await _sheetsService.findRowByIdInSheet(
          _spreadsheetId!,
          SheetConstants.categoriesSheet,
          category.id,
        );
        if (rowIndex > 0) {
          await _sheetsService.updateCategory(_spreadsheetId!, category, rowIndex);
        }
        break;
    }
  }

  Future<void> _syncAccount(String operation, Map<String, dynamic> data) async {
    final account = Account.fromJson(data);

    switch (operation) {
      case 'create':
        await _sheetsService.appendAccount(_spreadsheetId!, account);
        break;
      case 'update':
      case 'delete':
        final rowIndex = await _sheetsService.findRowByIdInSheet(
          _spreadsheetId!,
          SheetConstants.accountsSheet,
          account.id,
        );
        if (rowIndex > 0) {
          await _sheetsService.updateAccount(_spreadsheetId!, account, rowIndex);
        }
        break;
    }
  }

  Future<void> _syncBudget(String operation, Map<String, dynamic> data) async {
    final budget = Budget.fromJson(data);

    switch (operation) {
      case 'create':
        await _sheetsService.appendBudget(_spreadsheetId!, budget);
        break;
      case 'update':
      case 'delete':
        final rowIndex = await _sheetsService.findRowByIdInSheet(
          _spreadsheetId!,
          SheetConstants.budgetsSheet,
          budget.id,
        );
        if (rowIndex > 0) {
          await _sheetsService.updateBudget(_spreadsheetId!, budget, rowIndex);
        }
        break;
    }
  }

  Future<void> _syncPerson(String operation, Map<String, dynamic> data) async {
    final person = Person.fromJson(data);

    switch (operation) {
      case 'create':
        await _sheetsService.appendPerson(_spreadsheetId!, person);
        break;
      case 'update':
      case 'delete':
        final rowIndex = await _sheetsService.findRowByIdInSheet(
          _spreadsheetId!,
          SheetConstants.peopleSheet,
          person.id,
        );
        if (rowIndex > 0) {
          await _sheetsService.updatePerson(_spreadsheetId!, person, rowIndex);
        } else {
          throw Exception('Row not found for person ${person.id} in sheet');
        }
        break;
    }
  }

  Future<void> _syncLoan(String operation, Map<String, dynamic> data) async {
    final loan = Loan.fromJson(data);

    switch (operation) {
      case 'create':
        await _sheetsService.appendLoan(_spreadsheetId!, loan);
        break;
      case 'update':
      case 'delete':
        final rowIndex = await _sheetsService.findRowByIdInSheet(
          _spreadsheetId!,
          SheetConstants.loansSheet,
          loan.id,
        );
        if (rowIndex > 0) {
          await _sheetsService.updateLoan(_spreadsheetId!, loan, rowIndex);
        } else {
          throw Exception('Row not found for loan ${loan.id} in sheet');
        }
        break;
    }
  }

  /// Filters out items whose IDs are in the pending sync queue,
  /// so that a remote pull does not overwrite local changes (e.g. soft-deletes).
  List<T> _excludePending<T>(
      List<T> items, Set<String>? pendingIds, String Function(T) getId) {
    if (pendingIds == null || pendingIds.isEmpty) return items;
    return items.where((item) => !pendingIds.contains(getId(item))).toList();
  }

  /// Pulls remote changes incrementally. Returns true if ALL pulls succeeded.
  Future<bool> _pullRemoteChanges() async {
    bool allSucceeded = true;

    // Collect IDs of entities with pending local changes so we don't
    // overwrite them with stale remote data (e.g. un-deleting soft-deleted items).
    final pendingItems = await _syncQueueDao.getPending(limit: 10000);
    final pendingIdsByType = <String, Set<String>>{};
    for (final item in pendingItems) {
      pendingIdsByType
          .putIfAbsent(item.entityType, () => <String>{})
          .add(item.entityId);
    }

    // Pull transactions
    final transactions = await _pullWithRetry(
      () => _sheetsService.getAllTransactions(_spreadsheetId!),
      'transactions',
    );
    if (transactions != null && transactions.isNotEmpty) {
      final safe = _excludePending(
          transactions, pendingIdsByType['transaction'], (t) => t.id);
      if (safe.isNotEmpty) await _transactionDao.insertBatch(safe);
      debugPrint('Pulled ${safe.length} transactions from sheet'
          ' (${transactions.length - safe.length} skipped pending)');
    } else if (transactions == null) {
      allSucceeded = false;
    }

    // Pull categories
    final categories = await _pullWithRetry(
      () => _sheetsService.getAllCategories(_spreadsheetId!),
      'categories',
    );
    if (categories != null && categories.isNotEmpty) {
      final safe = _excludePending(
          categories, pendingIdsByType['category'], (c) => c.id);
      if (safe.isNotEmpty) await _categoryDao.insertBatch(safe);
      debugPrint('Pulled ${safe.length} categories from sheet'
          ' (${categories.length - safe.length} skipped pending)');
    } else if (categories == null) {
      allSucceeded = false;
    }

    // Pull accounts
    final accounts = await _pullWithRetry(
      () => _sheetsService.getAllAccounts(_spreadsheetId!),
      'accounts',
    );
    if (accounts != null && accounts.isNotEmpty) {
      final safe = _excludePending(
          accounts, pendingIdsByType['account'], (a) => a.id);
      if (safe.isNotEmpty) await _accountDao.insertBatch(safe);
      debugPrint('Pulled ${safe.length} accounts from sheet'
          ' (${accounts.length - safe.length} skipped pending)');
    } else if (accounts == null) {
      allSucceeded = false;
    }

    // Pull budgets
    final budgets = await _pullWithRetry(
      () => _sheetsService.getAllBudgets(_spreadsheetId!),
      'budgets',
    );
    if (budgets != null && budgets.isNotEmpty) {
      final safe = _excludePending(
          budgets, pendingIdsByType['budget'], (b) => b.id);
      if (safe.isNotEmpty) await _budgetDao.insertBatch(safe);
      debugPrint('Pulled ${safe.length} budgets from sheet'
          ' (${budgets.length - safe.length} skipped pending)');
    } else if (budgets == null) {
      allSucceeded = false;
    }

    // Pull people
    final people = await _pullWithRetry(
      () => _sheetsService.getAllPeople(_spreadsheetId!),
      'people',
    );
    if (people != null && people.isNotEmpty) {
      final safe = _excludePending(
          people, pendingIdsByType['person'], (p) => p.id);
      if (safe.isNotEmpty) await _personDao.insertBatch(safe);
      debugPrint('Pulled ${safe.length} people from sheet'
          ' (${people.length - safe.length} skipped pending)');
    } else if (people == null) {
      allSucceeded = false;
    }

    // Pull loans
    final loans = await _pullWithRetry(
      () => _sheetsService.getAllLoans(_spreadsheetId!),
      'loans',
    );
    if (loans != null && loans.isNotEmpty) {
      final safe = _excludePending(
          loans, pendingIdsByType['loan'], (l) => l.id);
      if (safe.isNotEmpty) await _loanDao.insertBatch(safe);
      debugPrint('Pulled ${safe.length} loans from sheet'
          ' (${loans.length - safe.length} skipped pending)');
    } else if (loans == null) {
      allSucceeded = false;
    }

    return allSucceeded;
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
