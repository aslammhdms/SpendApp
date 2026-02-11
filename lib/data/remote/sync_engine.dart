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
    required SyncQueueDao syncQueueDao,
  })  : _sheetsService = sheetsService,
        _transactionDao = transactionDao,
        _categoryDao = categoryDao,
        _accountDao = accountDao,
        _syncQueueDao = syncQueueDao;

  Future<void> initialize(String spreadsheetId) async {
    _spreadsheetId = spreadsheetId;
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
    return result != ConnectivityResult.none;
  }

  Future<void> sync() async {
    if (_isSyncing || _spreadsheetId == null) return;

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
      await _pullRemoteChanges();

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_at', DateTime.now().toIso8601String());

      _updateStatus(SyncStatus.synced);
    } catch (e) {
      debugPrint('Sync failed: $e');
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
      // Clear local data
      await _transactionDao.deleteAll();
      await _categoryDao.deleteAll();
      await _accountDao.deleteAll();
      await _syncQueueDao.deleteAll();

      // Pull all data from Sheets
      await _pullRemoteChanges();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_at', DateTime.now().toIso8601String());

      _updateStatus(SyncStatus.synced);
    } catch (e) {
      debugPrint('Full sync failed: $e');
      _updateStatus(SyncStatus.error);
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushPendingChanges() async {
    final pendingItems = await _syncQueueDao.getPending();

    for (final item in pendingItems) {
      try {
        await _processSyncItem(item);
        await _syncQueueDao.delete(item.id);
      } catch (e) {
        debugPrint('Failed to sync item ${item.id}: $e');
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
        }
        break;
    }
  }

  Future<void> _pullRemoteChanges() async {
    // Pull transactions
    final remoteTransactions = await _sheetsService.getAllTransactions(_spreadsheetId!);
    await _transactionDao.insertBatch(remoteTransactions);

    // Pull categories
    final remoteCategories = await _sheetsService.getAllCategories(_spreadsheetId!);
    await _categoryDao.insertBatch(remoteCategories);

    // Pull accounts
    final remoteAccounts = await _sheetsService.getAllAccounts(_spreadsheetId!);
    await _accountDao.insertBatch(remoteAccounts);
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
    final lastSync = prefs.getString('last_sync_at');
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
