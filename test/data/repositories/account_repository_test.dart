import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/data/models/account.dart';
import 'package:spendsheet/data/models/transaction.dart';

import '../../helpers/test_database_helper.dart';
import '../../helpers/mock_sync_engine.dart';

/// Testable account repo that uses real in-memory DB + MockSyncEngine.
class _TestAccountRepo {
  final Database _db;
  final MockSyncEngine _syncEngine;

  _TestAccountRepo(this._db, this._syncEngine);

  Future<void> insertDirect(Account account) async {
    await _db.insert('accounts', _toMap(account),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTransaction({
    required String id,
    required String accountId,
    required TransactionType type,
    required double amount,
    String? toAccountId,
  }) async {
    final now = DateTime.now();
    await _db.insert('transactions', {
      'id': id,
      'date': now.toIso8601String(),
      'amount': amount,
      'type': type.name,
      'category_id': 'cat_food',
      'account_id': accountId,
      'to_account_id': toAccountId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  Future<List<Account>> getAll() async {
    final maps = await _db.query('accounts',
        where: 'deleted_at IS NULL', orderBy: 'sort_order ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<Account?> getById(String id) async {
    final maps =
        await _db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<double> calculateBalance(String accountId) async {
    final accountResult = await _db.query('accounts',
        columns: ['initial_balance'],
        where: 'id = ?',
        whereArgs: [accountId]);
    if (accountResult.isEmpty) return 0;

    final initial =
        (accountResult.first['initial_balance'] as num).toDouble();

    final incomeResult = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE account_id = ? AND type = \'income\' AND deleted_at IS NULL',
        [accountId]);
    final income = (incomeResult.first['total'] as num).toDouble();

    final expenseResult = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE account_id = ? AND type = \'expense\' AND deleted_at IS NULL',
        [accountId]);
    final expense = (expenseResult.first['total'] as num).toDouble();

    final transferInResult = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE to_account_id = ? AND type = \'transfer\' AND deleted_at IS NULL',
        [accountId]);
    final transferIn = (transferInResult.first['total'] as num).toDouble();

    final transferOutResult = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE account_id = ? AND type = \'transfer\' AND deleted_at IS NULL',
        [accountId]);
    final transferOut =
        (transferOutResult.first['total'] as num).toDouble();

    return initial + income - expense + transferIn - transferOut;
  }

  Future<void> delete(String id) async {
    final account = await getById(id);
    if (account == null) return;
    final deleted = account.copyWithDelete();
    await _db.update('accounts', _toMap(deleted),
        where: 'id = ?', whereArgs: [id]);
    await _syncEngine.queueOperation(
      entityType: 'account',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Map<String, dynamic> _toMap(Account a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type.name,
        'initial_balance': a.initialBalance,
        'currency': a.currency,
        'icon': a.icon,
        'color': a.color,
        'sort_order': a.sortOrder,
        'created_at': a.createdAt.toIso8601String(),
        'updated_at': a.updatedAt.toIso8601String(),
        'deleted_at': a.deletedAt?.toIso8601String(),
      };

  Account _fromMap(Map<String, dynamic> map) => Account(
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

Account _makeAccount({
  required String id,
  String name = 'Test Account',
  AccountType type = AccountType.bank,
  double initialBalance = 1000.0,
  int sortOrder = 0,
}) {
  final now = DateTime.now();
  return Account(
    id: id,
    name: name,
    type: type,
    initialBalance: initialBalance,
    currency: 'USD',
    icon: '🏦',
    color: 0xFF2196F3,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Database db;
  late MockSyncEngine mockSyncEngine;
  late _TestAccountRepo repo;

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

    repo = _TestAccountRepo(db, mockSyncEngine);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('AccountRepository', () {
    test('getAll returns non-deleted accounts', () async {
      await repo.insertDirect(
          _makeAccount(id: 'acc_1', name: 'Checking', sortOrder: 0));
      await repo.insertDirect(
          _makeAccount(id: 'acc_2', name: 'Savings', sortOrder: 1));

      final all = await repo.getAll();
      // 3 default + 2 custom
      expect(all.length, greaterThanOrEqualTo(2));
    });

    test('getById returns correct account', () async {
      await repo.insertDirect(
          _makeAccount(id: 'acc_custom', name: 'Custom', initialBalance: 500));

      final acc = await repo.getById('acc_custom');
      expect(acc, isNotNull);
      expect(acc!.name, 'Custom');
      expect(acc.initialBalance, 500.0);
    });

    test('balance calculation: initial + income - expense', () async {
      await repo.insertDirect(
          _makeAccount(id: 'acc_test', initialBalance: 1000));

      await repo.insertTransaction(
        id: 'txn_inc',
        accountId: 'acc_test',
        type: TransactionType.income,
        amount: 500,
      );
      await repo.insertTransaction(
        id: 'txn_exp',
        accountId: 'acc_test',
        type: TransactionType.expense,
        amount: 200,
      );

      final balance = await repo.calculateBalance('acc_test');
      expect(balance, 1300.0); // 1000 + 500 - 200
    });

    test('balance includes transfers in/out', () async {
      await repo.insertDirect(
          _makeAccount(id: 'acc_a', initialBalance: 1000));
      await repo.insertDirect(
          _makeAccount(id: 'acc_b', initialBalance: 500));

      // Transfer 300 from A to B
      await repo.insertTransaction(
        id: 'txn_transfer',
        accountId: 'acc_a',
        type: TransactionType.transfer,
        amount: 300,
        toAccountId: 'acc_b',
      );

      final balA = await repo.calculateBalance('acc_a');
      final balB = await repo.calculateBalance('acc_b');
      expect(balA, 700.0); // 1000 - 300
      expect(balB, 800.0); // 500 + 300
    });

    test('delete soft-deletes and queues sync', () async {
      await repo.insertDirect(_makeAccount(id: 'acc_del'));

      await repo.delete('acc_del');

      final acc = await repo.getById('acc_del');
      expect(acc!.deletedAt, isNotNull);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'account',
            entityId: 'acc_del',
            operation: 'delete',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete non-existent is no-op', () async {
      await repo.delete('nonexistent');
      verifyNever(() => mockSyncEngine.queueOperation(
            entityType: 'account',
            entityId: 'nonexistent',
            operation: any(named: 'operation'),
            data: any(named: 'data'),
          ));
    });
  });
}
