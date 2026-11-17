import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import 'database_helper.dart';

class LocalAccountDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Account account) async {
    final db = await _db;
    return await db.insert(
      'accounts',
      _toMap(account),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Account account) async {
    final db = await _db;
    return await db.update(
      'accounts',
      _toMap(account),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'accounts',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Account?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Account>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('accounts', orderBy: 'sort_order ASC');
    } else {
      maps = await db.query(
        'accounts',
        where: 'deleted_at IS NULL',
        orderBy: 'sort_order ASC',
      );
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Account>> getByType(
    AccountType type, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = 'type = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'accounts',
      where: whereClause,
      whereArgs: [type.name],
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<int> getNextSortOrder() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order
      FROM accounts
    ''');
    return (result.first['next_order'] as num).toInt();
  }

  Future<void> updateSortOrders(List<Account> accounts) async {
    final db = await _db;
    final batch = db.batch();
    for (int i = 0; i < accounts.length; i++) {
      batch.update(
        'accounts',
        {
          'sort_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [accounts[i].id],
      );
    }
    await batch.commit();
  }

  Future<double> calculateBalance(String accountId) async {
    final db = await _db;

    // Get initial balance
    final accountResult = await db.query(
      'accounts',
      columns: ['initial_balance'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (accountResult.isEmpty) return 0;

    final initialBalance = (accountResult.first['initial_balance'] as num).toDouble();

    // Get income total
    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE account_id = ? AND type = 'income' AND deleted_at IS NULL
    ''', [accountId]);
    final incomeTotal = (incomeResult.first['total'] as num).toDouble();

    // Get expense total
    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE account_id = ? AND type = 'expense' AND deleted_at IS NULL
    ''', [accountId]);
    final expenseTotal = (expenseResult.first['total'] as num).toDouble();

    // Get transfers in
    final transferInResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE to_account_id = ? AND type = 'transfer' AND deleted_at IS NULL
    ''', [accountId]);
    final transferInTotal = (transferInResult.first['total'] as num).toDouble();

    // Get transfers out
    final transferOutResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE account_id = ? AND type = 'transfer' AND deleted_at IS NULL
    ''', [accountId]);
    final transferOutTotal = (transferOutResult.first['total'] as num).toDouble();

    return initialBalance + incomeTotal - expenseTotal + transferInTotal - transferOutTotal;
  }

  Future<Map<String, double>> calculateAllBalances() async {
    final accounts = await getAll();
    final balances = <String, double>{};
    for (final account in accounts) {
      balances[account.id] = await calculateBalance(account.id);
    }
    return balances;
  }

  Future<int> insertBatch(List<Account> accounts) async {
    final db = await _db;
    final batch = db.batch();
    for (final account in accounts) {
      batch.insert(
        'accounts',
        _toMap(account),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, 'accounts', except);
  }

  Map<String, dynamic> _toMap(Account account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      'initial_balance': account.initialBalance,
      'currency': account.currency,
      'icon': account.icon,
      'color': account.color,
      'sort_order': account.sortOrder,
      'created_at': account.createdAt.toIso8601String(),
      'updated_at': account.updatedAt.toIso8601String(),
      'deleted_at': account.deletedAt?.toIso8601String(),
    };
  }

  Account _fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AccountType.other,
      ),
      initialBalance: (map['initial_balance'] as num).toDouble(),
      currency: map['currency'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}
