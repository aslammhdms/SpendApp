import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = 'spendsheet.db';
  static const int _databaseVersion = 3;

  static Database? _database;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

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

    final expenseCategories = [
      {'id': 'cat_food', 'name': 'Food & Dining', 'icon': '🍔', 'color': 0xFFFF6B6B},
      {'id': 'cat_grocery', 'name': 'Groceries', 'icon': '🛒', 'color': 0xFF4ECDC4},
      {'id': 'cat_transport', 'name': 'Transportation', 'icon': '🚗', 'color': 0xFF45B7D1},
      {'id': 'cat_shopping', 'name': 'Shopping', 'icon': '🛍️', 'color': 0xFFFF8ED4},
      {'id': 'cat_entertainment', 'name': 'Entertainment', 'icon': '🎬', 'color': 0xFFFFBE0B},
      {'id': 'cat_bills', 'name': 'Bills & Utilities', 'icon': '📱', 'color': 0xFF7B68EE},
      {'id': 'cat_health', 'name': 'Healthcare', 'icon': '🏥', 'color': 0xFFFF6F61},
      {'id': 'cat_education', 'name': 'Education', 'icon': '📚', 'color': 0xFF00CED1},
      {'id': 'cat_personal', 'name': 'Personal Care', 'icon': '💅', 'color': 0xFFDDA0DD},
      {'id': 'cat_fitness', 'name': 'Fitness', 'icon': '🏋️', 'color': 0xFF98D8C8},
      {'id': 'cat_home', 'name': 'Home', 'icon': '🏠', 'color': 0xFFD4A574},
      {'id': 'cat_insurance', 'name': 'Insurance', 'icon': '🛡️', 'color': 0xFF778899},
      {'id': 'cat_travel', 'name': 'Travel', 'icon': '✈️', 'color': 0xFF87CEEB},
      {'id': 'cat_gifts', 'name': 'Gifts', 'icon': '🎁', 'color': 0xFFFF69B4},
      {'id': 'cat_subscriptions', 'name': 'Subscriptions', 'icon': '📺', 'color': 0xFF9370DB},
      {'id': 'cat_pets', 'name': 'Pets', 'icon': '🐾', 'color': 0xFFA0522D},
      {'id': 'cat_kids', 'name': 'Kids', 'icon': '👶', 'color': 0xFFFFB6C1},
      {'id': 'cat_taxes', 'name': 'Taxes', 'icon': '🧾', 'color': 0xFF696969},
      {'id': 'cat_investments', 'name': 'Investments', 'icon': '📈', 'color': 0xFF228B22},
      {'id': 'cat_other_expense', 'name': 'Other Expense', 'icon': '💸', 'color': 0xFF808080},
    ];

    final incomeCategories = [
      {'id': 'cat_salary', 'name': 'Salary', 'icon': '💰', 'color': 0xFF2ECC71},
      {'id': 'cat_freelance', 'name': 'Freelance', 'icon': '💻', 'color': 0xFF3498DB},
      {'id': 'cat_business', 'name': 'Business', 'icon': '🏢', 'color': 0xFF9B59B6},
      {'id': 'cat_invest_income', 'name': 'Investments', 'icon': '📊', 'color': 0xFF1ABC9C},
      {'id': 'cat_rental', 'name': 'Rental Income', 'icon': '🏘️', 'color': 0xFFE67E22},
      {'id': 'cat_gifts_received', 'name': 'Gifts Received', 'icon': '🎀', 'color': 0xFFE91E63},
      {'id': 'cat_refunds', 'name': 'Refunds', 'icon': '↩️', 'color': 0xFF00BCD4},
      {'id': 'cat_other_income', 'name': 'Other Income', 'icon': '💵', 'color': 0xFF607D8B},
    ];

    for (var i = 0; i < expenseCategories.length; i++) {
      final cat = expenseCategories[i];
      await db.insert('categories', {
        'id': cat['id'],
        'name': cat['name'],
        'type': 'expense',
        'icon': cat['icon'],
        'color': cat['color'],
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }

    for (var i = 0; i < incomeCategories.length; i++) {
      final cat = incomeCategories[i];
      await db.insert('categories', {
        'id': cat['id'],
        'name': cat['name'],
        'type': 'income',
        'icon': cat['icon'],
        'color': cat['color'],
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _insertDefaultAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();

    final accounts = [
      {'id': 'acc_cash', 'name': 'Cash', 'type': 'cash', 'icon': '💵', 'color': 0xFF4CAF50},
      {'id': 'acc_bank', 'name': 'Bank Account', 'type': 'bank', 'icon': '🏦', 'color': 0xFF2196F3},
      {'id': 'acc_credit', 'name': 'Credit Card', 'type': 'credit', 'icon': '💳', 'color': 0xFFF44336},
    ];

    for (var i = 0; i < accounts.length; i++) {
      final acc = accounts[i];
      await db.insert('accounts', {
        'id': acc['id'],
        'name': acc['name'],
        'type': acc['type'],
        'initial_balance': 0.0,
        'currency': 'USD',
        'icon': acc['icon'],
        'color': acc['color'],
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }
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
