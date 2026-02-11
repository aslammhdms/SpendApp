import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/loan.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around loan DAO logic that accepts a [Database]
/// parameter instead of using the DatabaseHelper singleton.
class TestLoanDao {
  final Database db;
  TestLoanDao(this.db);

  Future<int> insert(Loan loan) async {
    return await db.insert('loans', _toMap(loan),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> softDelete(String id) async {
    return await db.update(
        'loans', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Loan>> getAll({bool includeDeleted = false}) async {
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('loans', orderBy: 'date DESC');
    } else {
      maps = await db.query('loans',
          where: 'deleted_at IS NULL', orderBy: 'date DESC');
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Loan>> getByPersonId(String personId,
      {bool includeDeleted = false}) async {
    String whereClause = 'person_id = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query('loans',
        where: whereClause, whereArgs: [personId], orderBy: 'date DESC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<double> calculatePersonBalance(String personId) async {
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'lent' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'borrowed' THEN amount ELSE 0 END), 0) as balance
      FROM loans
      WHERE person_id = ? AND deleted_at IS NULL
    ''', [personId]);
    return (result.first['balance'] as num).toDouble();
  }

  Future<Map<String, double>> calculateAllBalances() async {
    final result = await db.rawQuery('''
      SELECT
        person_id,
        COALESCE(SUM(CASE WHEN type = 'lent' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'borrowed' THEN amount ELSE 0 END), 0) as balance
      FROM loans
      WHERE deleted_at IS NULL
      GROUP BY person_id
    ''');
    final balances = <String, double>{};
    for (final row in result) {
      balances[row['person_id'] as String] =
          (row['balance'] as num).toDouble();
    }
    return balances;
  }

  Map<String, dynamic> _toMap(Loan loan) {
    return {
      'id': loan.id,
      'person_id': loan.personId,
      'type': loan.type.name,
      'amount': loan.amount,
      'note': loan.note,
      'date': loan.date.toIso8601String(),
      'is_settlement': loan.isSettlement ? 1 : 0,
      'created_at': loan.createdAt.toIso8601String(),
      'updated_at': loan.updatedAt.toIso8601String(),
      'deleted_at': loan.deletedAt?.toIso8601String(),
    };
  }

  Loan _fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      type: LoanType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LoanType.lent,
      ),
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      isSettlement: (map['is_settlement'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}

void main() {
  late Database db;
  late TestLoanDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestLoanDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  Loan makeLoan({
    String id = 'l-1',
    String personId = 'p-1',
    LoanType type = LoanType.lent,
    double amount = 100.0,
    bool isSettlement = false,
  }) {
    final now = DateTime.now();
    return Loan(
      id: id,
      personId: personId,
      type: type,
      amount: amount,
      date: now,
      isSettlement: isSettlement,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('LocalLoanDao', () {
    test('insert and getAll', () async {
      await dao.insert(makeLoan());

      final loans = await dao.getAll();
      expect(loans.length, equals(1));
      expect(loans.first.id, equals('l-1'));
    });

    test('getByPersonId returns only matching loans', () async {
      await dao.insert(makeLoan(id: 'l-1', personId: 'p-1'));
      await dao.insert(makeLoan(id: 'l-2', personId: 'p-2'));
      await dao.insert(makeLoan(id: 'l-3', personId: 'p-1'));

      final loans = await dao.getByPersonId('p-1');
      expect(loans.length, equals(2));
      expect(loans.every((l) => l.personId == 'p-1'), isTrue);
    });

    test('calculatePersonBalance computes lent minus borrowed', () async {
      await dao.insert(
          makeLoan(id: 'l-1', personId: 'p-1', type: LoanType.lent, amount: 100));
      await dao.insert(makeLoan(
          id: 'l-2', personId: 'p-1', type: LoanType.borrowed, amount: 30));
      await dao.insert(
          makeLoan(id: 'l-3', personId: 'p-1', type: LoanType.lent, amount: 50));

      final balance = await dao.calculatePersonBalance('p-1');
      expect(balance, equals(120.0)); // 100 + 50 - 30
    });

    test('calculateAllBalances groups by person', () async {
      await dao.insert(
          makeLoan(id: 'l-1', personId: 'p-1', type: LoanType.lent, amount: 100));
      await dao.insert(makeLoan(
          id: 'l-2', personId: 'p-2', type: LoanType.borrowed, amount: 50));

      final balances = await dao.calculateAllBalances();
      expect(balances['p-1'], equals(100.0));
      expect(balances['p-2'], equals(-50.0));
    });

    test('soft deleted loans excluded from balance', () async {
      await dao.insert(
          makeLoan(id: 'l-1', personId: 'p-1', type: LoanType.lent, amount: 100));
      await dao.insert(
          makeLoan(id: 'l-2', personId: 'p-1', type: LoanType.lent, amount: 200));

      await dao.softDelete('l-2');

      final balance = await dao.calculatePersonBalance('p-1');
      expect(balance, equals(100.0));
    });

    test('soft deleted loans excluded from getAll but included with flag',
        () async {
      await dao.insert(makeLoan(id: 'l-1'));
      await dao.insert(makeLoan(id: 'l-2'));
      await dao.softDelete('l-2');

      expect((await dao.getAll()).length, equals(1));
      expect((await dao.getAll(includeDeleted: true)).length, equals(2));
    });

    test('settlement loans are tracked correctly', () async {
      // Lent 100 to p-1
      await dao.insert(
          makeLoan(id: 'l-1', personId: 'p-1', type: LoanType.lent, amount: 100));
      // Settlement: they paid back 60 (recorded as borrowed)
      await dao.insert(makeLoan(
          id: 'l-2',
          personId: 'p-1',
          type: LoanType.borrowed,
          amount: 60,
          isSettlement: true));

      final balance = await dao.calculatePersonBalance('p-1');
      expect(balance, equals(40.0)); // 100 - 60
    });
  });
}
