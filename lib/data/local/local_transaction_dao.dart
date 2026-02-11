import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/transaction.dart';
import 'database_helper.dart';

class LocalTransactionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Transaction transaction) async {
    final db = await _db;
    return await db.insert(
      'transactions',
      _toMap(transaction),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Transaction transaction) async {
    final db = await _db;
    return await db.update(
      'transactions',
      _toMap(transaction),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'transactions',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Transaction?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Transaction>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('transactions', orderBy: 'date DESC');
    } else {
      maps = await db.query(
        'transactions',
        where: 'deleted_at IS NULL',
        orderBy: 'date DESC',
      );
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByDateRange(
    DateTime startDate,
    DateTime endDate, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = 'date >= ? AND date <= ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByCategory(
    String categoryId, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = 'category_id = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: [categoryId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByAccount(
    String accountId, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = '(account_id = ? OR to_account_id = ?)';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getByType(
    TransactionType type, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = 'type = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: [type.name],
      orderBy: 'date DESC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getRecent(int limit) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transaction>> getPaginated(int offset, int limit) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
      offset: offset,
      limit: limit,
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<double> getTotalByTypeAndDateRange(
    TransactionType type,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = ?
        AND date >= ?
        AND date <= ?
        AND deleted_at IS NULL
    ''', [type.name, startDate.toIso8601String(), endDate.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalByCategoryAndDateRange(
    String categoryId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE category_id = ?
        AND date >= ?
        AND date <= ?
        AND deleted_at IS NULL
    ''', [categoryId, startDate.toIso8601String(), endDate.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getTotalsByCategory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE date >= ?
        AND date <= ?
        AND deleted_at IS NULL
        AND type = 'expense'
      GROUP BY category_id
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['category_id'] as String,
        (row['total'] as num).toDouble(),
      )),
    );
  }

  Future<int> insertBatch(List<Transaction> transactions) async {
    final db = await _db;
    final batch = db.batch();
    for (final transaction in transactions) {
      batch.insert(
        'transactions',
        _toMap(transaction),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  Future<int> deleteAll() async {
    final db = await _db;
    return await db.delete('transactions');
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
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
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
