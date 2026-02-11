import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/account.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around account DAO logic that accepts a [Database]
/// parameter instead of using the DatabaseHelper singleton.
class TestAccountDao {
  final Database db;
  TestAccountDao(this.db);

  Future<int> insert(Account account) async {
    return await db.insert('accounts', _toMap(account),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(Account account) async {
    return await db.update('accounts', _toMap(account),
        where: 'id = ?', whereArgs: [account.id]);
  }

  Future<int> softDelete(String id) async {
    return await db.update(
        'accounts', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Account?> getById(String id) async {
    final maps = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Account>> getAll({bool includeDeleted = false}) async {
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('accounts', orderBy: 'sort_order ASC');
    } else {
      maps = await db.query('accounts',
          where: 'deleted_at IS NULL', orderBy: 'sort_order ASC');
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<double> calculateBalance(String accountId) async {
    final accountResult = await db.query('accounts',
        columns: ['initial_balance'],
        where: 'id = ?',
        whereArgs: [accountId]);
    if (accountResult.isEmpty) return 0;
    final initialBalance =
        (accountResult.first['initial_balance'] as num).toDouble();

    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE account_id = ? AND type = 'income' AND deleted_at IS NULL
    ''', [accountId]);
    final incomeTotal = (incomeResult.first['total'] as num).toDouble();

    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE account_id = ? AND type = 'expense' AND deleted_at IS NULL
    ''', [accountId]);
    final expenseTotal = (expenseResult.first['total'] as num).toDouble();

    final transferInResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE to_account_id = ? AND type = 'transfer' AND deleted_at IS NULL
    ''', [accountId]);
    final transferInTotal =
        (transferInResult.first['total'] as num).toDouble();

    final transferOutResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE account_id = ? AND type = 'transfer' AND deleted_at IS NULL
    ''', [accountId]);
    final transferOutTotal =
        (transferOutResult.first['total'] as num).toDouble();

    return initialBalance + incomeTotal - expenseTotal + transferInTotal -
        transferOutTotal;
  }

  Future<Map<String, double>> calculateAllBalances() async {
    final accounts = await getAll();
    final balances = <String, double>{};
    for (final account in accounts) {
      balances[account.id] = await calculateBalance(account.id);
    }
    return balances;
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
      type: AccountType.values.firstWhere((e) => e.name == map['type'],
          orElse: () => AccountType.other),
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

/// Helper to insert a transaction directly into the test database.
Future<void> _insertTransaction(
  Database db, {
  required String id,
  required String accountId,
  required String type,
  required double amount,
  String? toAccountId,
  String? deletedAt,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert('transactions', {
    'id': id,
    'date': now,
    'amount': amount,
    'type': type,
    'category_id': 'cat_food',
    'account_id': accountId,
    'to_account_id': toAccountId,
    'note': null,
    'receipt_url': null,
    'recurring_id': null,
    'created_at': now,
    'updated_at': now,
    'deleted_at': deletedAt,
  });
}

void main() {
  late Database db;
  late TestAccountDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestAccountDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('AccountDao', () {
    test('getAll returns 3 default accounts', () async {
      final accounts = await dao.getAll();
      expect(accounts.length, equals(3));
    });

    test('insert adds a new account', () async {
      final now = DateTime.now();
      final account = Account(
        id: 'acc_test',
        name: 'Test Account',
        type: AccountType.savings,
        initialBalance: 1000.0,
        currency: 'USD',
        icon: '🏦',
        color: 0xFF00FF00,
        sortOrder: 10,
        createdAt: now,
        updatedAt: now,
      );

      await dao.insert(account);
      final result = await dao.getById('acc_test');
      expect(result, isNotNull);
      expect(result!.name, equals('Test Account'));
      expect(result.initialBalance, equals(1000.0));
    });

    test('update modifies existing account', () async {
      final original = await dao.getById('acc_cash');
      expect(original, isNotNull);

      final updated = original!.copyWith(name: 'Updated Cash');
      await dao.update(updated);

      final result = await dao.getById('acc_cash');
      expect(result!.name, equals('Updated Cash'));
    });

    test('softDelete sets deleted_at and excludes from getAll', () async {
      await dao.softDelete('acc_cash');

      final all = await dao.getAll();
      expect(all.length, equals(2));
      expect(all.any((a) => a.id == 'acc_cash'), isFalse);

      // But still exists with includeDeleted
      final allIncluding = await dao.getAll(includeDeleted: true);
      expect(allIncluding.length, equals(3));
    });

    test('getById returns correct account', () async {
      final result = await dao.getById('acc_bank');
      expect(result, isNotNull);
      expect(result!.name, equals('Bank Account'));
      expect(result.type, equals(AccountType.bank));
    });

    test('calculateBalance with no transactions returns 0 (initial_balance)',
        () async {
      final balance = await dao.calculateBalance('acc_cash');
      expect(balance, equals(0.0));
    });

    test('calculateBalance with income adds to balance', () async {
      await _insertTransaction(db,
          id: 'txn_1', accountId: 'acc_cash', type: 'income', amount: 500.0);
      await _insertTransaction(db,
          id: 'txn_2', accountId: 'acc_cash', type: 'income', amount: 300.0);

      final balance = await dao.calculateBalance('acc_cash');
      expect(balance, equals(800.0));
    });

    test('calculateBalance with expense subtracts from balance', () async {
      await _insertTransaction(db,
          id: 'txn_1', accountId: 'acc_cash', type: 'income', amount: 1000.0);
      await _insertTransaction(db,
          id: 'txn_2', accountId: 'acc_cash', type: 'expense', amount: 250.0);

      final balance = await dao.calculateBalance('acc_cash');
      expect(balance, equals(750.0));
    });

    test('calculateBalance with transfers in/out', () async {
      // Transfer 200 from cash to bank
      await _insertTransaction(db,
          id: 'txn_transfer',
          accountId: 'acc_cash',
          type: 'transfer',
          amount: 200.0,
          toAccountId: 'acc_bank');

      final cashBalance = await dao.calculateBalance('acc_cash');
      expect(cashBalance, equals(-200.0)); // 0 - 200 transfer out

      final bankBalance = await dao.calculateBalance('acc_bank');
      expect(bankBalance, equals(200.0)); // 0 + 200 transfer in
    });

    test('calculateAllBalances returns map for all accounts', () async {
      await _insertTransaction(db,
          id: 'txn_1', accountId: 'acc_cash', type: 'income', amount: 100.0);

      final balances = await dao.calculateAllBalances();
      expect(balances.length, equals(3));
      expect(balances['acc_cash'], equals(100.0));
      expect(balances['acc_bank'], equals(0.0));
      expect(balances['acc_credit'], equals(0.0));
    });

    test('soft-deleted transactions excluded from balance calculation',
        () async {
      await _insertTransaction(db,
          id: 'txn_1', accountId: 'acc_cash', type: 'income', amount: 500.0);
      await _insertTransaction(db,
          id: 'txn_2',
          accountId: 'acc_cash',
          type: 'income',
          amount: 300.0,
          deletedAt: DateTime.now().toIso8601String());

      final balance = await dao.calculateBalance('acc_cash');
      expect(balance, equals(500.0)); // Only non-deleted txn counted
    });
  });
}
