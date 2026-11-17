import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/category_defaults.dart';

class DatabaseHelper {
  static const String _databaseName = 'spendsheet.db';
  static const int _databaseVersion = 3;

  static Database? _database;

  /// Lets tests open a throwaway database (for example
  /// `inMemoryDatabasePath`) instead of the app's file.
  @visibleForTesting
  static String? pathOverride;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = pathOverride ?? join(await getDatabasesPath(), _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        note TEXT,
        receipt_url TEXT,
        recurring_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initial_balance REAL NOT NULL,
        currency TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        period TEXT NOT NULL,
        category_id TEXT,
        start_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_rules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        frequency TEXT NOT NULL,
        interval_value INTEGER NOT NULL,
        next_due_date TEXT NOT NULL,
        end_date TEXT,
        note TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        error_message TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category_id)');
    await db.execute('CREATE INDEX idx_transactions_account ON transactions(account_id)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_categories_type ON categories(type)');
    await db.execute('CREATE INDEX idx_budgets_category ON budgets(category_id)');
    await db.execute('CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id)');

    await db.execute('''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        is_settlement INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_loans_person ON loans(person_id)');
    await db.execute('CREATE INDEX idx_loans_type ON loans(type)');

    // Insert default categories and accounts
    await _insertDefaultCategories(db);
    await _insertDefaultAccounts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final categories = await db.query('categories');
      if (categories.isEmpty) {
        await _insertDefaultCategories(db);
      }

      final accounts = await db.query('accounts');
      if (accounts.isEmpty) {
        await _insertDefaultAccounts(db);
      }
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE people (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE loans (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          date TEXT NOT NULL,
          is_settlement INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT
        )
      ''');

      await db.execute('CREATE INDEX idx_loans_person ON loans(person_id)');
      await db.execute('CREATE INDEX idx_loans_type ON loans(type)');
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();

    Future<void> insertAll(
        List<DefaultCategory> categories, String type) async {
      for (var i = 0; i < categories.length; i++) {
        final cat = categories[i];
        await db.insert('categories', {
          'id': cat.id,
          'name': cat.name,
          'type': type,
          'icon': cat.icon,
          'color': cat.color,
          'sort_order': i,
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    await insertAll(CategoryDefaults.expenseCategories, 'expense');
    await insertAll(CategoryDefaults.incomeCategories, 'income');
  }

  Future<void> _insertDefaultAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();

    const accounts = CategoryDefaults.defaultAccounts;
    for (var i = 0; i < accounts.length; i++) {
      final acc = accounts[i];
      await db.insert('accounts', {
        'id': acc.id,
        'name': acc.name,
        'type': acc.type,
        'initial_balance': 0.0,
        'currency': 'USD',
        'icon': acc.icon,
        'color': acc.color,
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Deletes every row of [table] whose `id` is not in [keepIds].
  static Future<int> deleteAllExcept(
    DatabaseExecutor db,
    String table,
    Set<String> keepIds,
  ) async {
    if (keepIds.isEmpty) return db.delete(table);

    final rows = await db.query(table, columns: ['id']);
    final doomed = rows
        .map((row) => row['id'] as String)
        .where((id) => !keepIds.contains(id))
        .toList();

    // Chunked to stay under SQLite's limit on bound parameters.
    const chunkSize = 500;
    var deleted = 0;
    for (var i = 0; i < doomed.length; i += chunkSize) {
      final chunk = doomed.sublist(i, min(i + chunkSize, doomed.length));
      deleted += await db.delete(
        table,
        where: 'id IN (${List.filled(chunk.length, '?').join(', ')})',
        whereArgs: chunk,
      );
    }
    return deleted;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('categories');
    await db.delete('accounts');
    await db.delete('budgets');
    await db.delete('recurring_rules');
    await db.delete('sync_queue');
    await db.delete('settings');
    await db.delete('people');
    await db.delete('loans');
  }
}
