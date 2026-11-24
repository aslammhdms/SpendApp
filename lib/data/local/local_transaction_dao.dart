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

  /// IDs of the categories that live transactions use.
  Future<Set<String>> getUsedCategoryIds() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category_id FROM transactions WHERE deleted_at IS NULL',
    );
    return rows.map((row) => row['category_id'] as String).toSet();
  }

  /// How many live transactions dated on or after [since] use each category.
  /// Categories with none are left out.
  Future<Map<String, int>> getCategoryUseCounts(DateTime since) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT category_id, COUNT(*) AS uses FROM transactions '
      'WHERE deleted_at IS NULL AND date >= ? GROUP BY category_id',
      [since.toIso8601String()],
    );
    return {
      for (final row in rows) row['category_id'] as String: row['uses'] as int,
    };
  }

  /// IDs of the accounts that live transactions use, as source or target.
  Future<Set<String>> getUsedAccountIds() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT account_id AS id FROM transactions WHERE deleted_at IS NULL
      UNION
      SELECT to_account_id AS id FROM transactions
      WHERE deleted_at IS NULL AND to_account_id IS NOT NULL
    ''');
    return rows.map((row) => row['id'] as String).toSet();
  }

  /// Every label on a live transaction, most used first, each in its most
  /// common spelling.
  Future<List<String>> getAllLabels() async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      columns: ['labels'],
      where: "deleted_at IS NULL AND labels IS NOT NULL AND labels != ''",
    );
    final spellings = _LabelSpellings();
    for (final row in rows) {
      Transaction.splitLabels(row['labels'] as String?).forEach(spellings.add);
    }
    final keys = spellings.keys.toList()
      ..sort((a, b) {
        final byUse = spellings.uses(b).compareTo(spellings.uses(a));
        return byUse != 0 ? byUse : a.compareTo(b);
      });
    return [for (final k in keys) spellings.of(k)];
  }

  /// Expense totals by label for transactions dated from [start] to [end],
  /// keyed by the label's most common spelling. A transaction with two
  /// labels counts towards both.
  Future<Map<String, double>> getExpenseTotalsByLabel(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await getByLabelRange(start, end);
    final totals = <String, double>{};
    final spellings = _LabelSpellings();
    for (final t in rows) {
      if (t.type != TransactionType.expense) continue;
      for (final label in t.labels) {
        spellings.add(label);
        final key = label.toLowerCase();
        totals[key] = (totals[key] ?? 0) + t.amount;
      }
    }
    return {for (final e in totals.entries) spellings.of(e.key): e.value};
  }

  /// Live labelled transactions dated from [start] to [end].
  Future<List<Transaction>> getByLabelRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: "deleted_at IS NULL AND labels IS NOT NULL AND labels != '' "
          'AND date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(_fromMap).toList();
  }

  /// Live transactions dated from [start] to [end] that carry [label]
  /// (ignoring case).
  Future<List<Transaction>> getByLabel(
    String label, {
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _db;
    var where = "deleted_at IS NULL AND labels IS NOT NULL AND labels != ''";
    final args = <Object>[];
    if (start != null) {
      where += ' AND date >= ?';
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where += ' AND date <= ?';
      args.add(end.toIso8601String());
    }
    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );
    final wanted = label.toLowerCase();
    return maps
        .map(_fromMap)
        .where((t) => t.labels.any((l) => l.toLowerCase() == wanted))
        .toList();
  }

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, 'transactions', except);
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
      'labels': transaction.labels.isEmpty
          ? null
          : Transaction.joinLabels(transaction.labels),
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
      labels: Transaction.splitLabels(map['labels'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}

/// Counts labels that differ only in case, and picks the spelling used most
/// (alphabetically first on a tie), so the same label always shows the same
/// way whatever order the rows come in.
class _LabelSpellings {
  final _counts = <String, Map<String, int>>{};

  void add(String label) {
    final forms = _counts.putIfAbsent(label.toLowerCase(), () => {});
    forms[label] = (forms[label] ?? 0) + 1;
  }

  Iterable<String> get keys => _counts.keys;

  int uses(String key) =>
      _counts[key]?.values.fold<int>(0, (a, b) => a + b) ?? 0;

  String of(String key) {
    final forms = _counts[key]!.entries.toList()
      ..sort((a, b) {
        final byUse = b.value.compareTo(a.value);
        return byUse != 0 ? byUse : a.key.compareTo(b.key);
      });
    return forms.first.key;
  }
}
