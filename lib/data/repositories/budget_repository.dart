import 'package:sqflite/sqflite.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../local/database_helper.dart';
import '../local/local_transaction_dao.dart';
import '../local/sync_queue_dao.dart';
import '../remote/sync_engine.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/date_utils.dart';

class BudgetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalTransactionDao _transactionDao;
  final SyncQueueDao _syncQueueDao;
  final SyncEngine _syncEngine;

  BudgetRepository({
    required LocalTransactionDao transactionDao,
    required SyncQueueDao syncQueueDao,
    required SyncEngine syncEngine,
  })  : _transactionDao = transactionDao,
        _syncQueueDao = syncQueueDao,
        _syncEngine = syncEngine;

  Future<Database> get _db => _dbHelper.database;

  Future<List<Budget>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps;

    if (includeDeleted) {
      maps = await db.query('budgets');
    } else {
      maps = await db.query(
        'budgets',
        where: 'deleted_at IS NULL',
      );
    }

    final budgets = maps.map((map) => _fromMap(map)).toList();

    // Calculate spent amounts
    return await Future.wait(budgets.map((budget) async {
      final spent = await _calculateSpentAmount(budget);
      return budget.copyWith(spentAmount: spent);
    }));
  }

  Future<Budget?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final budget = _fromMap(maps.first);
    final spent = await _calculateSpentAmount(budget);
    return budget.copyWith(spentAmount: spent);
  }

  Future<List<Budget>> getByCategoryId(String categoryId) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'category_id = ? AND deleted_at IS NULL',
      whereArgs: [categoryId],
    );

    final budgets = maps.map((map) => _fromMap(map)).toList();

    return await Future.wait(budgets.map((budget) async {
      final spent = await _calculateSpentAmount(budget);
      return budget.copyWith(spentAmount: spent);
    }));
  }

  Future<double> _calculateSpentAmount(Budget budget) async {
    final dateRange = _getDateRangeForPeriod(budget.period, budget.startDate);

    if (budget.categoryId != null) {
      return await _transactionDao.getTotalByCategoryAndDateRange(
        budget.categoryId!,
        dateRange.$1,
        dateRange.$2,
      );
    } else {
      // Overall budget - sum all expenses
      return await _transactionDao.getTotalByTypeAndDateRange(
        TransactionType.expense,
        dateRange.$1,
        dateRange.$2,
      );
    }
  }

  (DateTime, DateTime) _getDateRangeForPeriod(BudgetPeriod period, DateTime startDate) {
    final now = DateTime.now();

    switch (period) {
      case BudgetPeriod.weekly:
        final weekStart = AppDateUtils.startOfWeek(now);
        final weekEnd = AppDateUtils.endOfWeek(now);
        return (weekStart, weekEnd);
      case BudgetPeriod.monthly:
        final monthStart = AppDateUtils.startOfMonth(now);
        final monthEnd = AppDateUtils.endOfMonth(now);
        return (monthStart, monthEnd);
      case BudgetPeriod.yearly:
        final yearStart = AppDateUtils.startOfYear(now);
        final yearEnd = AppDateUtils.endOfYear(now);
        return (yearStart, yearEnd);
    }
  }

  Future<Budget> create({
    required String name,
    required double amount,
    required BudgetPeriod period,
    String? categoryId,
    DateTime? startDate,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    final budget = Budget(
      id: IdGenerator.generate(),
      name: name,
      amount: amount,
      period: period,
      categoryId: categoryId,
      startDate: startDate ?? now,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('budgets', _toMap(budget));

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'budget',
      entityId: budget.id,
      operation: 'create',
      data: budget.toJson(),
    );

    return budget;
  }

  Future<Budget> update(Budget budget) async {
    final db = await _db;
    final updated = budget.copyWith(updatedAt: DateTime.now());

    await db.update(
      'budgets',
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'budget',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );

    return updated;
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final budget = await getById(id);
    if (budget == null) return;

    final deleted = budget.copyWithDelete();

    await db.update(
      'budgets',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'budget',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<List<Budget>> getOverBudget() async {
    final budgets = await getAll();
    return budgets.where((b) => b.isOverBudget).toList();
  }

  Future<List<Budget>> getWarningBudgets() async {
    final budgets = await getAll();
    return budgets.where((b) => b.isWarning).toList();
  }

  Map<String, dynamic> _toMap(Budget budget) {
    return {
      'id': budget.id,
      'name': budget.name,
      'amount': budget.amount,
      'period': budget.period.name,
      'category_id': budget.categoryId,
      'start_date': budget.startDate.toIso8601String(),
      'created_at': budget.createdAt.toIso8601String(),
      'updated_at': budget.updatedAt.toIso8601String(),
      'deleted_at': budget.deletedAt?.toIso8601String(),
    };
  }

  Budget _fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (e) => e.name == map['period'],
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryId: map['category_id'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}
