import '../models/transaction.dart';
import '../local/local_transaction_dao.dart';
import '../local/sync_queue_dao.dart';
import '../remote/sync_engine.dart';
import '../../core/utils/id_generator.dart';

class TransactionRepository {
  final LocalTransactionDao _localDao;
  final SyncEngine _syncEngine;

  TransactionRepository({
    required LocalTransactionDao localDao,
    // Unused: changes are queued through the sync engine. Kept so callers
    // do not have to change.
    required SyncQueueDao syncQueueDao,
    required SyncEngine syncEngine,
  })  : _localDao = localDao,
        _syncEngine = syncEngine;

  Future<List<Transaction>> getAll({bool includeDeleted = false}) async {
    return await _localDao.getAll(includeDeleted: includeDeleted);
  }

  Future<Transaction?> getById(String id) async {
    return await _localDao.getById(id);
  }

  Future<List<Transaction>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _localDao.getByDateRange(startDate, endDate);
  }

  Future<List<Transaction>> getByCategory(String categoryId) async {
    return await _localDao.getByCategory(categoryId);
  }

  Future<List<Transaction>> getByAccount(String accountId) async {
    return await _localDao.getByAccount(accountId);
  }

  Future<List<Transaction>> getByType(TransactionType type) async {
    return await _localDao.getByType(type);
  }

  Future<List<Transaction>> getRecent(int limit) async {
    return await _localDao.getRecent(limit);
  }

  Future<List<Transaction>> getPaginated(int offset, int limit) async {
    return await _localDao.getPaginated(offset, limit);
  }

  Future<Transaction> create({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    String? toAccountId,
    DateTime? date,
    String? note,
    String? receiptUrl,
    String? recurringId,
  }) async {
    final now = DateTime.now();
    final transaction = Transaction(
      id: IdGenerator.generate(),
      date: date ?? now,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      note: note,
      receiptUrl: receiptUrl,
      recurringId: recurringId,
      createdAt: now,
      updatedAt: now,
    );

    // Save locally first
    await _localDao.insert(transaction);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'transaction',
      entityId: transaction.id,
      operation: 'create',
      data: transaction.toJson(),
    );

    return transaction;
  }

  Future<Transaction> update(Transaction transaction) async {
    final updated = transaction.copyWith(updatedAt: DateTime.now());

    // Update locally first
    await _localDao.update(updated);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'transaction',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );

    return updated;
  }

  Future<void> delete(String id) async {
    final transaction = await _localDao.getById(id);
    if (transaction == null) return;

    final deleted = transaction.copyWithDelete();

    // Soft delete locally
    await _localDao.update(deleted);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'transaction',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<double> getTotalByTypeAndDateRange(
    TransactionType type,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _localDao.getTotalByTypeAndDateRange(type, startDate, endDate);
  }

  Future<double> getTotalByCategoryAndDateRange(
    String categoryId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _localDao.getTotalByCategoryAndDateRange(
      categoryId,
      startDate,
      endDate,
    );
  }

  Future<Map<String, double>> getTotalsByCategory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _localDao.getTotalsByCategory(startDate, endDate);
  }

  /// How many transactions since [since] used each category.
  Future<Map<String, int>> getCategoryUseCounts(DateTime since) async {
    return await _localDao.getCategoryUseCounts(since);
  }

  Future<double> getMonthlyIncome(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return await getTotalByTypeAndDateRange(
      TransactionType.income,
      startDate,
      endDate,
    );
  }

  Future<double> getMonthlyExpense(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return await getTotalByTypeAndDateRange(
      TransactionType.expense,
      startDate,
      endDate,
    );
  }

  Future<Map<DateTime, double>> getDailySpending(int days) async {
    final now = DateTime.now();
    final result = <DateTime, double>{};

    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final total = await getTotalByTypeAndDateRange(
        TransactionType.expense,
        startDate,
        endDate,
      );
      result[date] = total;
    }

    return result;
  }
}
