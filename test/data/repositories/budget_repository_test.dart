import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/data/models/transaction.dart';

import '../../helpers/test_database_helper.dart';
import '../../helpers/mock_sync_engine.dart';

/// Testable budget repo using real in-memory DB + MockSyncEngine.
/// Mirrors BudgetRepository which uses DB directly (not a DAO for CRUD).
class _TestBudgetRepo {
  final Database _db;
  final MockSyncEngine _syncEngine;

  _TestBudgetRepo(this._db, this._syncEngine);

  Future<List<Budget>> getAll() async {
    final maps = await _db.query('budgets', where: 'deleted_at IS NULL');
    final budgets = maps.map((m) => _fromMap(m)).toList();
    return await Future.wait(budgets.map((b) async {
      final spent = await _calculateSpent(b);
      return b.copyWith(spentAmount: spent);
    }));
  }

  Future<Budget?> getById(String id) async {
    final maps =
        await _db.query('budgets', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final b = _fromMap(maps.first);
    final spent = await _calculateSpent(b);
    return b.copyWith(spentAmount: spent);
  }

  Future<Budget> create({
    required String id,
    required String name,
    required double amount,
    required BudgetPeriod period,
    String? categoryId,
    DateTime? startDate,
  }) async {
    final now = DateTime.now();
    final budget = Budget(
      id: id,
      name: name,
      amount: amount,
      period: period,
      categoryId: categoryId,
      startDate: startDate ?? now,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('budgets', _toMap(budget));
    await _syncEngine.queueOperation(
      entityType: 'budget',
      entityId: budget.id,
      operation: 'create',
      data: budget.toJson(),
    );
    return budget;
  }

  Future<void> delete(String id) async {
    final budget = await getById(id);
    if (budget == null) return;
    await _db.update(
      'budgets',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncEngine.queueOperation(
      entityType: 'budget',
      entityId: id,
      operation: 'delete',
      data: budget.copyWithDelete().toJson(),
    );
  }

  Future<void> insertTransaction({
    required String id,
    required String accountId,
    required TransactionType type,
    required String categoryId,
    required double amount,
    required DateTime date,
  }) async {
    await _db.insert('transactions', {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'account_id': accountId,
      'created_at': date.toIso8601String(),
      'updated_at': date.toIso8601String(),
    });
  }

  Future<double> _calculateSpent(Budget budget) async {
    final now = DateTime.now();
    late DateTime start, end;
    switch (budget.period) {
      case BudgetPeriod.weekly:
        final weekday = now.weekday;
        start = DateTime(now.year, now.month, now.day - (weekday - 1));
        end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case BudgetPeriod.monthly:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case BudgetPeriod.yearly:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }

    if (budget.categoryId != null) {
      final result = await _db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE category_id = ? AND type = \'expense\' AND date >= ? AND date <= ? AND deleted_at IS NULL',
          [budget.categoryId, start.toIso8601String(), end.toIso8601String()]);
      return (result.first['total'] as num).toDouble();
    } else {
      final result = await _db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = \'expense\' AND date >= ? AND date <= ? AND deleted_at IS NULL',
          [start.toIso8601String(), end.toIso8601String()]);
      return (result.first['total'] as num).toDouble();
    }
  }

  Map<String, dynamic> _toMap(Budget b) => {
        'id': b.id,
        'name': b.name,
        'amount': b.amount,
        'period': b.period.name,
        'category_id': b.categoryId,
        'start_date': b.startDate.toIso8601String(),
        'created_at': b.createdAt.toIso8601String(),
        'updated_at': b.updatedAt.toIso8601String(),
        'deleted_at': b.deletedAt?.toIso8601String(),
      };

  Budget _fromMap(Map<String, dynamic> map) => Budget(
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

void main() {
  late Database db;
  late MockSyncEngine mockSyncEngine;
  late _TestBudgetRepo repo;

  setUpAll(() {
    initTestDatabase();
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() async {
    db = await createTestDatabase();
    mockSyncEngine = MockSyncEngine();

    when(() => mockSyncEngine.queueOperation(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});

    repo = _TestBudgetRepo(db, mockSyncEngine);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('BudgetRepository', () {
    test('create inserts and queues sync', () async {
      final b = await repo.create(
        id: 'bud_1',
        name: 'Food Budget',
        amount: 500,
        period: BudgetPeriod.monthly,
        categoryId: 'cat_food',
      );

      expect(b.id, 'bud_1');
      expect(b.name, 'Food Budget');

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'budget',
            entityId: 'bud_1',
            operation: 'create',
            data: any(named: 'data'),
          )).called(1);
    });

    test('getAll excludes soft-deleted', () async {
      await repo.create(
        id: 'bud_1', name: 'Active', amount: 500,
        period: BudgetPeriod.monthly,
      );
      await repo.create(
        id: 'bud_2', name: 'ToDelete', amount: 300,
        period: BudgetPeriod.weekly,
      );

      await repo.delete('bud_2');

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, 'bud_1');
    });

    test('getById returns with computed spentAmount', () async {
      final now = DateTime.now();
      await repo.create(
        id: 'bud_food', name: 'Food', amount: 500,
        period: BudgetPeriod.monthly, categoryId: 'cat_food',
      );

      await repo.insertTransaction(
        id: 'txn_1', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_food',
        amount: 100, date: now,
      );
      await repo.insertTransaction(
        id: 'txn_2', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_food',
        amount: 50, date: now,
      );

      final b = await repo.getById('bud_food');
      expect(b, isNotNull);
      expect(b!.spentAmount, 150.0);
    });

    test('overall budget sums all expenses', () async {
      final now = DateTime.now();
      await repo.create(
        id: 'bud_overall', name: 'Overall', amount: 2000,
        period: BudgetPeriod.monthly, categoryId: null,
      );

      await repo.insertTransaction(
        id: 'txn_food', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_food',
        amount: 100, date: now,
      );
      await repo.insertTransaction(
        id: 'txn_transport', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_transport',
        amount: 200, date: now,
      );
      // Income should NOT count
      await repo.insertTransaction(
        id: 'txn_inc', accountId: 'acc_bank',
        type: TransactionType.income, categoryId: 'cat_salary',
        amount: 5000, date: now,
      );

      final b = await repo.getById('bud_overall');
      expect(b!.spentAmount, 300.0);
    });

    test('delete soft-deletes and queues sync', () async {
      await repo.create(
        id: 'bud_del', name: 'Delete Me', amount: 100,
        period: BudgetPeriod.weekly,
      );

      await repo.delete('bud_del');

      final b = await repo.getById('bud_del');
      expect(b!.deletedAt, isNotNull);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'budget',
            entityId: 'bud_del',
            operation: 'delete',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete non-existent is no-op', () async {
      await repo.delete('nonexistent');
      verifyNever(() => mockSyncEngine.queueOperation(
            entityType: 'budget',
            entityId: 'nonexistent',
            operation: any(named: 'operation'),
            data: any(named: 'data'),
          ));
    });

    test('spentAmount only counts current period', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);

      await repo.create(
        id: 'bud_monthly', name: 'Food', amount: 500,
        period: BudgetPeriod.monthly, categoryId: 'cat_food',
      );

      // This month
      await repo.insertTransaction(
        id: 'txn_this', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_food',
        amount: 100, date: now,
      );
      // Last month
      await repo.insertTransaction(
        id: 'txn_last', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_food',
        amount: 200, date: lastMonth,
      );

      final b = await repo.getById('bud_monthly');
      expect(b!.spentAmount, 100.0); // Only this month
    });

    test('getById returns null for missing', () async {
      final b = await repo.getById('nonexistent');
      expect(b, isNull);
    });

    test('isOverBudget and isWarning computed correctly', () async {
      final now = DateTime.now();
      await repo.create(
        id: 'bud_test', name: 'Test', amount: 100,
        period: BudgetPeriod.monthly, categoryId: 'cat_food',
      );

      // Spend 90 (warning zone 80-99%)
      await repo.insertTransaction(
        id: 'txn_90', accountId: 'acc_cash',
        type: TransactionType.expense, categoryId: 'cat_food',
        amount: 90, date: now,
      );

      final b = await repo.getById('bud_test');
      expect(b!.isWarning, isTrue);
      expect(b.isOverBudget, isFalse);
    });
  });
}
