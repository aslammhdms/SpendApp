import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/data/models/transaction.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around transaction DAO logic that accepts a [Database]
/// parameter instead of using the DatabaseHelper singleton.
class TestTransactionDao {
  final Database db;
  TestTransactionDao(this.db);

  Future<int> insert(Transaction transaction) async {
    return await db.insert('transactions', _toMap(transaction),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(Transaction transaction) async {
    return await db.update('transactions', _toMap(transaction),
        where: 'id = ?', whereArgs: [transaction.id]);
  }

  Future<int> softDelete(String id) async {
    return await db.update(
        'transactions', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Transaction?> getById(String id) async {
    final maps =
        await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Transaction>> getAll({bool includeDeleted = false}) async {
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('transactions', orderBy: 'date DESC');
    } else {
      maps = await db.query('transactions',
          where: 'deleted_at IS NULL', orderBy: 'date DESC');
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByDateRange(
      DateTime startDate, DateTime endDate,
      {bool includeDeleted = false}) async {
    String whereClause = 'date >= ? AND date <= ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query('transactions',
        where: whereClause,
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'date DESC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByCategory(String categoryId,
      {bool includeDeleted = false}) async {
    String whereClause = 'category_id = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query('transactions',
        where: whereClause, whereArgs: [categoryId], orderBy: 'date DESC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByAccount(String accountId,
      {bool includeDeleted = false}) async {
    String whereClause = '(account_id = ? OR to_account_id = ?)';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query('transactions',
        where: whereClause,
        whereArgs: [accountId, accountId],
        orderBy: 'date DESC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByType(TransactionType type,
      {bool includeDeleted = false}) async {
    String whereClause = 'type = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query('transactions',
        where: whereClause, whereArgs: [type.name], orderBy: 'date DESC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getRecent(int limit) async {
    final maps = await db.query('transactions',
        where: 'deleted_at IS NULL', orderBy: 'date DESC', limit: limit);
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getPaginated(int offset, int limit) async {
    final maps = await db.query('transactions',
        where: 'deleted_at IS NULL',
        orderBy: 'date DESC',
        offset: offset,
        limit: limit);
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<double> getTotalByTypeAndDateRange(
      TransactionType type, DateTime startDate, DateTime endDate) async {
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = ? AND date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [type.name, startDate.toIso8601String(), endDate.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalByCategoryAndDateRange(
      String categoryId, DateTime startDate, DateTime endDate) async {
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE category_id = ? AND date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [
      categoryId,
      startDate.toIso8601String(),
      endDate.toIso8601String()
    ]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getTotalsByCategory(
      DateTime startDate, DateTime endDate) async {
    final result = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL AND type = 'expense'
      GROUP BY category_id
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    return Map.fromEntries(result.map((row) => MapEntry(
        row['category_id'] as String, (row['total'] as num).toDouble())));
  }

  Map<String, dynamic> _toMap(Transaction transaction) {
    return {
      'id': transaction.id,
      'date': transaction.date.toIso8601String(),
      'amount': transaction.amount,
      'type': transaction.type.name,
      'category_id': transaction.categoryId,
      'account_id': transaction.accountId,
      'to_account_id': transaction.toAccountId,
      'note': transaction.note,
      'receipt_url': transaction.receiptUrl,
      'recurring_id': transaction.recurringId,
      'created_at': transaction.createdAt.toIso8601String(),
      'updated_at': transaction.updatedAt.toIso8601String(),
      'deleted_at': transaction.deletedAt?.toIso8601String(),
    };
  }

  Transaction _fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere((e) => e.name == map['type'],
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
}

Transaction _makeTransaction({
  required String id,
  DateTime? date,
  double amount = 100.0,
  TransactionType type = TransactionType.expense,
  String categoryId = 'cat_food',
  String accountId = 'acc_cash',
  String? toAccountId,
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
    toAccountId: toAccountId,
    note: note,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Database db;
  late TestTransactionDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestTransactionDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('TransactionDao', () {
    test('insert and getById roundtrip', () async {
      final txn = _makeTransaction(
        id: 'txn_1',
        amount: 42.50,
        note: 'Lunch',
      );
      await dao.insert(txn);

      final result = await dao.getById('txn_1');
      expect(result, isNotNull);
      expect(result!.amount, equals(42.50));
      expect(result.note, equals('Lunch'));
      expect(result.type, equals(TransactionType.expense));
    });

    test('getAll ordered by date DESC', () async {
      final older = _makeTransaction(
          id: 'txn_old', date: DateTime(2024, 1, 1), amount: 10);
      final newer = _makeTransaction(
          id: 'txn_new', date: DateTime(2024, 6, 15), amount: 20);
      final newest = _makeTransaction(
          id: 'txn_newest', date: DateTime(2024, 12, 31), amount: 30);

      await dao.insert(older);
      await dao.insert(newest);
      await dao.insert(newer);

      final all = await dao.getAll();
      expect(all.length, equals(3));
      expect(all[0].id, equals('txn_newest'));
      expect(all[1].id, equals('txn_new'));
      expect(all[2].id, equals('txn_old'));
    });

    test('getByDateRange filters correctly', () async {
      await dao.insert(_makeTransaction(
          id: 'txn_jan', date: DateTime(2024, 1, 15)));
      await dao.insert(_makeTransaction(
          id: 'txn_mar', date: DateTime(2024, 3, 10)));
      await dao.insert(_makeTransaction(
          id: 'txn_jun', date: DateTime(2024, 6, 20)));

      final results = await dao.getByDateRange(
          DateTime(2024, 2, 1), DateTime(2024, 4, 30));
      expect(results.length, equals(1));
      expect(results.first.id, equals('txn_mar'));
    });

    test('getByCategory filters correctly', () async {
      await dao.insert(
          _makeTransaction(id: 'txn_food', categoryId: 'cat_food'));
      await dao.insert(
          _makeTransaction(id: 'txn_transport', categoryId: 'cat_transport'));
      await dao.insert(
          _makeTransaction(id: 'txn_food2', categoryId: 'cat_food'));

      final results = await dao.getByCategory('cat_food');
      expect(results.length, equals(2));
      for (final r in results) {
        expect(r.categoryId, equals('cat_food'));
      }
    });

    test('getByAccount includes both account_id and to_account_id', () async {
      await dao.insert(
          _makeTransaction(id: 'txn_from', accountId: 'acc_cash'));
      await dao.insert(_makeTransaction(
        id: 'txn_transfer',
        accountId: 'acc_bank',
        type: TransactionType.transfer,
        toAccountId: 'acc_cash',
      ));
      await dao.insert(
          _makeTransaction(id: 'txn_other', accountId: 'acc_bank'));

      final results = await dao.getByAccount('acc_cash');
      expect(results.length, equals(2));
      final ids = results.map((r) => r.id).toSet();
      expect(ids, contains('txn_from'));
      expect(ids, contains('txn_transfer'));
    });

    test('getByType filters correctly', () async {
      await dao.insert(_makeTransaction(
          id: 'txn_exp', type: TransactionType.expense));
      await dao.insert(_makeTransaction(
          id: 'txn_inc', type: TransactionType.income));
      await dao.insert(_makeTransaction(
          id: 'txn_exp2', type: TransactionType.expense));

      final expenses = await dao.getByType(TransactionType.expense);
      expect(expenses.length, equals(2));

      final incomes = await dao.getByType(TransactionType.income);
      expect(incomes.length, equals(1));
    });

    test('getRecent respects limit', () async {
      for (int i = 0; i < 10; i++) {
        await dao.insert(_makeTransaction(
            id: 'txn_$i', date: DateTime(2024, 1, i + 1)));
      }

      final recent = await dao.getRecent(3);
      expect(recent.length, equals(3));
    });

    test('getPaginated with offset and limit', () async {
      for (int i = 0; i < 10; i++) {
        await dao.insert(_makeTransaction(
            id: 'txn_$i', date: DateTime(2024, 1, i + 1)));
      }

      final page1 = await dao.getPaginated(0, 3);
      expect(page1.length, equals(3));

      final page2 = await dao.getPaginated(3, 3);
      expect(page2.length, equals(3));

      // Pages should not overlap
      final page1Ids = page1.map((t) => t.id).toSet();
      final page2Ids = page2.map((t) => t.id).toSet();
      expect(page1Ids.intersection(page2Ids), isEmpty);
    });

    test('softDelete excludes from normal queries', () async {
      await dao.insert(_makeTransaction(id: 'txn_1'));
      await dao.insert(_makeTransaction(id: 'txn_2'));

      await dao.softDelete('txn_1');

      final all = await dao.getAll();
      expect(all.length, equals(1));
      expect(all.first.id, equals('txn_2'));

      // Still accessible via includeDeleted
      final allIncluding = await dao.getAll(includeDeleted: true);
      expect(allIncluding.length, equals(2));
    });

    test('getTotalByTypeAndDateRange sums correctly', () async {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);

      await dao.insert(_makeTransaction(
          id: 'txn_1',
          date: DateTime(2024, 3, 1),
          type: TransactionType.expense,
          amount: 100));
      await dao.insert(_makeTransaction(
          id: 'txn_2',
          date: DateTime(2024, 5, 1),
          type: TransactionType.expense,
          amount: 200));
      await dao.insert(_makeTransaction(
          id: 'txn_3',
          date: DateTime(2024, 7, 1),
          type: TransactionType.income,
          amount: 500));

      final expenseTotal =
          await dao.getTotalByTypeAndDateRange(TransactionType.expense, start, end);
      expect(expenseTotal, equals(300.0));

      final incomeTotal =
          await dao.getTotalByTypeAndDateRange(TransactionType.income, start, end);
      expect(incomeTotal, equals(500.0));
    });

    test('getTotalByCategoryAndDateRange sums correctly', () async {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);

      await dao.insert(_makeTransaction(
          id: 'txn_1',
          date: DateTime(2024, 3, 1),
          categoryId: 'cat_food',
          amount: 50));
      await dao.insert(_makeTransaction(
          id: 'txn_2',
          date: DateTime(2024, 5, 1),
          categoryId: 'cat_food',
          amount: 75));
      await dao.insert(_makeTransaction(
          id: 'txn_3',
          date: DateTime(2024, 7, 1),
          categoryId: 'cat_transport',
          amount: 200));

      final foodTotal =
          await dao.getTotalByCategoryAndDateRange('cat_food', start, end);
      expect(foodTotal, equals(125.0));
    });

    test('getTotalsByCategory groups by category for expenses only', () async {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);

      await dao.insert(_makeTransaction(
          id: 'txn_1',
          date: DateTime(2024, 3, 1),
          categoryId: 'cat_food',
          type: TransactionType.expense,
          amount: 50));
      await dao.insert(_makeTransaction(
          id: 'txn_2',
          date: DateTime(2024, 5, 1),
          categoryId: 'cat_food',
          type: TransactionType.expense,
          amount: 30));
      await dao.insert(_makeTransaction(
          id: 'txn_3',
          date: DateTime(2024, 7, 1),
          categoryId: 'cat_transport',
          type: TransactionType.expense,
          amount: 100));
      // Income should NOT appear in expense totals
      await dao.insert(_makeTransaction(
          id: 'txn_4',
          date: DateTime(2024, 7, 1),
          categoryId: 'cat_salary',
          type: TransactionType.income,
          amount: 5000));

      final totals = await dao.getTotalsByCategory(start, end);
      expect(totals['cat_food'], equals(80.0));
      expect(totals['cat_transport'], equals(100.0));
      expect(totals.containsKey('cat_salary'), isFalse);
    });
  });
}
