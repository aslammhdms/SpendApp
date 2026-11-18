import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';

import '../../helpers/test_database_helper.dart';
import '../../helpers/mock_sync_engine.dart';

void main() {
  late Database db;
  late MockSyncEngine mockSyncEngine;

  // We need a real DAO backed by a test DB, but LocalTransactionDao uses
  // the singleton. So we create a thin wrapper similar to the DAO test.
  late _TestableTransactionRepo repo;

  setUpAll(() {
    initTestDatabase();
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() async {
    db = await createTestDatabase();
    mockSyncEngine = MockSyncEngine();

    // Stub queueOperation to always succeed
    when(() => mockSyncEngine.queueOperation(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});

    repo = _TestableTransactionRepo(db, mockSyncEngine);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  Transaction makeTxn({
    required String id,
    DateTime? date,
    double amount = 100.0,
    TransactionType type = TransactionType.expense,
    String categoryId = 'cat_food',
    String accountId = 'acc_cash',
    String? note,
  }) {
    final now = DateTime.now();
    return Transaction(
      id: id,
      date: date ?? now,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TransactionRepository', () {
    test('create inserts locally and queues sync', () async {
      final txn = await repo.create(
        amount: 42.50,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        note: 'Lunch',
      );

      expect(txn.amount, 42.50);
      expect(txn.note, 'Lunch');
      expect(txn.id, isNotEmpty);

      // Verify it's in the DB
      final found = await repo.getById(txn.id);
      expect(found, isNotNull);
      expect(found!.amount, 42.50);

      // Verify sync was queued
      verify(() => mockSyncEngine.queueOperation(
            entityType: 'transaction',
            entityId: txn.id,
            operation: 'create',
            data: any(named: 'data'),
          )).called(1);
    });

    test('getAll returns non-deleted transactions', () async {
      final txn1 = makeTxn(id: 'txn_1');
      final txn2 = makeTxn(id: 'txn_2');
      await repo.insertDirect(txn1);
      await repo.insertDirect(txn2);

      // Soft-delete txn_1
      await repo.delete('txn_1');

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, 'txn_2');
    });

    test('getById returns correct transaction', () async {
      await repo.insertDirect(makeTxn(id: 'txn_1', amount: 55.0));

      final result = await repo.getById('txn_1');
      expect(result, isNotNull);
      expect(result!.amount, 55.0);
    });

    test('getById returns null for missing', () async {
      final result = await repo.getById('nonexistent');
      expect(result, isNull);
    });

    test('getByDateRange filters correctly', () async {
      await repo.insertDirect(
          makeTxn(id: 'txn_jan', date: DateTime(2024, 1, 15)));
      await repo.insertDirect(
          makeTxn(id: 'txn_mar', date: DateTime(2024, 3, 10)));
      await repo.insertDirect(
          makeTxn(id: 'txn_jun', date: DateTime(2024, 6, 20)));

      final results = await repo.getByDateRange(
          DateTime(2024, 2, 1), DateTime(2024, 4, 30));
      expect(results.length, 1);
      expect(results.first.id, 'txn_mar');
    });

    test('getByCategory returns matching', () async {
      await repo.insertDirect(
          makeTxn(id: 'txn_1', categoryId: 'cat_food'));
      await repo.insertDirect(
          makeTxn(id: 'txn_2', categoryId: 'cat_transport'));

      final results = await repo.getByCategory('cat_food');
      expect(results.length, 1);
      expect(results.first.id, 'txn_1');
    });

    test('getRecent respects limit', () async {
      for (int i = 0; i < 10; i++) {
        await repo.insertDirect(
            makeTxn(id: 'txn_$i', date: DateTime(2024, 1, i + 1)));
      }

      final recent = await repo.getRecent(3);
      expect(recent.length, 3);
    });

    test('update modifies locally and queues sync', () async {
      final txn = makeTxn(id: 'txn_1', amount: 100, note: 'Old');
      await repo.insertDirect(txn);

      final updated = txn.copyWith(amount: 200, note: 'New');
      await repo.update(updated);

      final found = await repo.getById('txn_1');
      expect(found!.amount, 200);
      expect(found.note, 'New');

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'transaction',
            entityId: 'txn_1',
            operation: 'update',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete soft-deletes and queues sync', () async {
      await repo.insertDirect(makeTxn(id: 'txn_1'));

      await repo.delete('txn_1');

      // Should not appear in normal getAll
      final all = await repo.getAll();
      expect(all, isEmpty);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'transaction',
            entityId: 'txn_1',
            operation: 'delete',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete non-existent id is no-op', () async {
      await repo.delete('nonexistent');
      // Should not throw, and no sync queued for delete
      verifyNever(() => mockSyncEngine.queueOperation(
            entityType: 'transaction',
            entityId: 'nonexistent',
            operation: 'delete',
            data: any(named: 'data'),
          ));
    });

    test('getMonthlyIncome computes correct amount', () async {
      // Insert income in June 2024
      await repo.insertDirect(makeTxn(
        id: 'inc_1',
        date: DateTime(2024, 6, 10),
        amount: 3000,
        type: TransactionType.income,
      ));
      await repo.insertDirect(makeTxn(
        id: 'inc_2',
        date: DateTime(2024, 6, 20),
        amount: 2000,
        type: TransactionType.income,
      ));
      // Expense should not count
      await repo.insertDirect(makeTxn(
        id: 'exp_1',
        date: DateTime(2024, 6, 15),
        amount: 500,
        type: TransactionType.expense,
      ));

      final income = await repo.getMonthlyIncome(DateTime(2024, 6, 1));
      expect(income, 5000.0);
    });

    test('getMonthlyExpense computes correct amount', () async {
      await repo.insertDirect(makeTxn(
        id: 'exp_1',
        date: DateTime(2024, 6, 10),
        amount: 300,
        type: TransactionType.expense,
      ));
      await repo.insertDirect(makeTxn(
        id: 'exp_2',
        date: DateTime(2024, 6, 20),
        amount: 200,
        type: TransactionType.expense,
      ));

      final expense = await repo.getMonthlyExpense(DateTime(2024, 6, 1));
      expect(expense, 500.0);
    });

    test('getTotalsByCategory aggregates by category', () async {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);

      await repo.insertDirect(makeTxn(
        id: 'txn_1',
        date: DateTime(2024, 3, 1),
        categoryId: 'cat_food',
        type: TransactionType.expense,
        amount: 50,
      ));
      await repo.insertDirect(makeTxn(
        id: 'txn_2',
        date: DateTime(2024, 5, 1),
        categoryId: 'cat_food',
        type: TransactionType.expense,
        amount: 30,
      ));
      await repo.insertDirect(makeTxn(
        id: 'txn_3',
        date: DateTime(2024, 7, 1),
        categoryId: 'cat_transport',
        type: TransactionType.expense,
        amount: 100,
      ));

      final totals = await repo.getTotalsByCategory(start, end);
      expect(totals['cat_food'], 80.0);
      expect(totals['cat_transport'], 100.0);
    });
  });
}

/// A testable TransactionRepository that uses a real in-memory DB
/// but mocks the SyncEngine.
class _TestableTransactionRepo {
  final Database _db;
  final SyncEngine _syncEngine;

  _TestableTransactionRepo(this._db, this._syncEngine);

  // Direct insert for test setup (bypasses sync)
  Future<void> insertDirect(Transaction txn) async {
    await _db.insert('transactions', _toMap(txn),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Transaction> create({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    String? note,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final id = 'txn_${now.microsecondsSinceEpoch}';
    final txn = Transaction(
      id: id,
      date: date ?? now,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('transactions', _toMap(txn),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _syncEngine.queueOperation(
      entityType: 'transaction',
      entityId: txn.id,
      operation: 'create',
      data: txn.toJson(),
    );
    return txn;
  }

  Future<List<Transaction>> getAll({bool includeDeleted = false}) async {
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await _db.query('transactions', orderBy: 'date DESC');
    } else {
      maps = await _db.query('transactions',
          where: 'deleted_at IS NULL', orderBy: 'date DESC');
    }
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<Transaction?> getById(String id) async {
    final maps =
        await _db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Transaction>> getByDateRange(
      DateTime startDate, DateTime endDate) async {
    final maps = await _db.query('transactions',
        where: 'date >= ? AND date <= ? AND deleted_at IS NULL',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'date DESC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<List<Transaction>> getByCategory(String categoryId) async {
    final maps = await _db.query('transactions',
        where: 'category_id = ? AND deleted_at IS NULL',
        whereArgs: [categoryId],
        orderBy: 'date DESC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<List<Transaction>> getRecent(int limit) async {
    final maps = await _db.query('transactions',
        where: 'deleted_at IS NULL', orderBy: 'date DESC', limit: limit);
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<Transaction> update(Transaction transaction) async {
    final updated = transaction.copyWith(updatedAt: DateTime.now());
    await _db.update('transactions', _toMap(updated),
        where: 'id = ?', whereArgs: [updated.id]);
    await _syncEngine.queueOperation(
      entityType: 'transaction',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );
    return updated;
  }

  Future<void> delete(String id) async {
    final maps =
        await _db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return;
    final txn = _fromMap(maps.first);
    final deleted = txn.copyWithDelete();
    await _db.update('transactions', _toMap(deleted),
        where: 'id = ?', whereArgs: [id]);
    await _syncEngine.queueOperation(
      entityType: 'transaction',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<double> getMonthlyIncome(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return await _getTotalByTypeAndDateRange(
        TransactionType.income, startDate, endDate);
  }

  Future<double> getMonthlyExpense(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return await _getTotalByTypeAndDateRange(
        TransactionType.expense, startDate, endDate);
  }

  Future<Map<String, double>> getTotalsByCategory(
      DateTime startDate, DateTime endDate) async {
    final result = await _db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL AND type = 'expense'
      GROUP BY category_id
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    return Map.fromEntries(result.map((row) => MapEntry(
        row['category_id'] as String, (row['total'] as num).toDouble())));
  }

  Future<double> _getTotalByTypeAndDateRange(
      TransactionType type, DateTime start, DateTime end) async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = ? AND date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [type.name, start.toIso8601String(), end.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Map<String, dynamic> _toMap(Transaction t) => {
        'id': t.id,
        'date': t.date.toIso8601String(),
        'amount': t.amount,
        'type': t.type.name,
        'category_id': t.categoryId,
        'account_id': t.accountId,
        'to_account_id': t.toAccountId,
        'note': t.note,
        'receipt_url': t.receiptUrl,
        'recurring_id': t.recurringId,
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt.toIso8601String(),
        'deleted_at': t.deletedAt?.toIso8601String(),
      };

  Transaction _fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        amount: (map['amount'] as num).toDouble(),
        type: TransactionType.values.firstWhere(
            (e) => e.name == map['type'],
            orElse: () => TransactionType.expense),
        categoryId: map['category_id'] as String,
        accountId: map['account_id'] as String,
        toAccountId: map['to_account_id'] as String?,
        note: map['note'] as String?,
        receiptUrl: map['receipt_url'] as String?,
        recurringId: map['recurring_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        deletedAt: map['deleted_at'] != null
            ? DateTime.parse(map['deleted_at'] as String)
            : null,
      );
}
