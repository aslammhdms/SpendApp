import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/loan.dart';

import '../../helpers/test_database_helper.dart';
import '../../helpers/mock_sync_engine.dart';

/// Testable loan repo using real in-memory DB + MockSyncEngine.
class _TestLoanRepo {
  final Database _db;
  final MockSyncEngine _syncEngine;

  _TestLoanRepo(this._db, this._syncEngine);

  Future<void> insertPerson(String id, String name) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert('people', {
      'id': id,
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<Loan> create({
    required String id,
    required String personId,
    required LoanType type,
    required double amount,
    required DateTime date,
    String? note,
    bool isSettlement = false,
  }) async {
    final now = DateTime.now();
    final loan = Loan(
      id: id,
      personId: personId,
      type: type,
      amount: amount,
      note: note,
      date: date,
      isSettlement: isSettlement,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('loans', _toMap(loan));
    await _syncEngine.queueOperation(
      entityType: 'loan',
      entityId: loan.id,
      operation: 'create',
      data: loan.toJson(),
    );
    return loan;
  }

  Future<Loan?> getById(String id) async {
    final maps =
        await _db.query('loans', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Loan>> getByPersonId(String personId) async {
    final maps = await _db.query('loans',
        where: 'person_id = ? AND deleted_at IS NULL',
        whereArgs: [personId],
        orderBy: 'date DESC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<double> getPersonBalance(String personId) async {
    final lentResult = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM loans WHERE person_id = ? AND type = \'lent\' AND deleted_at IS NULL',
        [personId]);
    final lent = (lentResult.first['total'] as num).toDouble();

    final borrowedResult = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM loans WHERE person_id = ? AND type = \'borrowed\' AND deleted_at IS NULL',
        [personId]);
    final borrowed = (borrowedResult.first['total'] as num).toDouble();

    return lent - borrowed;
  }

  Future<double> getTotalOwedToYou() async {
    // Sum of positive person balances
    final people = await _db.query('people', where: 'deleted_at IS NULL');
    double total = 0;
    for (final p in people) {
      final balance = await getPersonBalance(p['id'] as String);
      if (balance > 0) total += balance;
    }
    return total;
  }

  Future<double> getTotalYouOwe() async {
    final people = await _db.query('people', where: 'deleted_at IS NULL');
    double total = 0;
    for (final p in people) {
      final balance = await getPersonBalance(p['id'] as String);
      if (balance < 0) total += balance.abs();
    }
    return total;
  }

  Future<void> delete(String id) async {
    final loan = await getById(id);
    if (loan == null) return;
    final deleted = loan.copyWithDelete();
    await _db.update('loans', _toMap(deleted),
        where: 'id = ?', whereArgs: [id]);
    await _syncEngine.queueOperation(
      entityType: 'loan',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<Loan> settle({
    required String personId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final balance = await getPersonBalance(personId);
    // Positive balance → they owe you → settlement is "borrowed"
    // Negative balance → you owe them → settlement is "lent"
    final type = balance > 0 ? LoanType.borrowed : LoanType.lent;

    return create(
      id: 'settle_${DateTime.now().millisecondsSinceEpoch}',
      personId: personId,
      type: type,
      amount: amount,
      date: date,
      note: note,
      isSettlement: true,
    );
  }

  Map<String, dynamic> _toMap(Loan l) => {
        'id': l.id,
        'person_id': l.personId,
        'type': l.type.name,
        'amount': l.amount,
        'note': l.note,
        'date': l.date.toIso8601String(),
        'is_settlement': l.isSettlement ? 1 : 0,
        'created_at': l.createdAt.toIso8601String(),
        'updated_at': l.updatedAt.toIso8601String(),
        'deleted_at': l.deletedAt?.toIso8601String(),
      };

  Loan _fromMap(Map<String, dynamic> map) => Loan(
        id: map['id'] as String,
        personId: map['person_id'] as String,
        type: LoanType.values.firstWhere((e) => e.name == map['type'],
            orElse: () => LoanType.lent),
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

void main() {
  late Database db;
  late MockSyncEngine mockSyncEngine;
  late _TestLoanRepo repo;

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

    repo = _TestLoanRepo(db, mockSyncEngine);
    await repo.insertPerson('per_alice', 'Alice');
    await repo.insertPerson('per_bob', 'Bob');
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('LoanRepository', () {
    test('create inserts and queues sync', () async {
      final loan = await repo.create(
        id: 'loan_1',
        personId: 'per_alice',
        type: LoanType.lent,
        amount: 100,
        date: DateTime.now(),
        note: 'Dinner',
      );

      expect(loan.id, 'loan_1');
      expect(loan.type, LoanType.lent);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'loan',
            entityId: 'loan_1',
            operation: 'create',
            data: any(named: 'data'),
          )).called(1);
    });

    test('getByPersonId returns only matching', () async {
      await repo.create(
        id: 'loan_a', personId: 'per_alice', type: LoanType.lent,
        amount: 100, date: DateTime.now(),
      );
      await repo.create(
        id: 'loan_b', personId: 'per_bob', type: LoanType.borrowed,
        amount: 50, date: DateTime.now(),
      );

      final aliceLoans = await repo.getByPersonId('per_alice');
      expect(aliceLoans.length, 1);
      expect(aliceLoans.first.id, 'loan_a');
    });

    test('getPersonBalance: lent - borrowed', () async {
      await repo.create(
        id: 'loan_1', personId: 'per_alice', type: LoanType.lent,
        amount: 300, date: DateTime.now(),
      );
      await repo.create(
        id: 'loan_2', personId: 'per_alice', type: LoanType.borrowed,
        amount: 100, date: DateTime.now(),
      );

      final balance = await repo.getPersonBalance('per_alice');
      expect(balance, 200.0); // 300 - 100
    });

    test('getTotalOwedToYou sums positive balances', () async {
      // Alice owes us 200
      await repo.create(
        id: 'loan_1', personId: 'per_alice', type: LoanType.lent,
        amount: 200, date: DateTime.now(),
      );
      // We owe Bob 100
      await repo.create(
        id: 'loan_2', personId: 'per_bob', type: LoanType.borrowed,
        amount: 100, date: DateTime.now(),
      );

      final total = await repo.getTotalOwedToYou();
      expect(total, 200.0);
    });

    test('getTotalYouOwe sums negative balances', () async {
      await repo.create(
        id: 'loan_1', personId: 'per_alice', type: LoanType.lent,
        amount: 200, date: DateTime.now(),
      );
      await repo.create(
        id: 'loan_2', personId: 'per_bob', type: LoanType.borrowed,
        amount: 100, date: DateTime.now(),
      );

      final total = await repo.getTotalYouOwe();
      expect(total, 100.0);
    });

    test('delete soft-deletes and queues sync', () async {
      await repo.create(
        id: 'loan_del', personId: 'per_alice', type: LoanType.lent,
        amount: 50, date: DateTime.now(),
      );

      await repo.delete('loan_del');

      final loan = await repo.getById('loan_del');
      expect(loan!.deletedAt, isNotNull);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'loan',
            entityId: 'loan_del',
            operation: 'delete',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete non-existent is no-op', () async {
      await repo.delete('nonexistent');
      verifyNever(() => mockSyncEngine.queueOperation(
            entityType: 'loan',
            entityId: 'nonexistent',
            operation: any(named: 'operation'),
            data: any(named: 'data'),
          ));
    });

    test('settle positive balance creates borrowed settlement', () async {
      // Alice owes us 500 (lent)
      await repo.create(
        id: 'loan_lent', personId: 'per_alice', type: LoanType.lent,
        amount: 500, date: DateTime.now(),
      );

      final settlement = await repo.settle(
        personId: 'per_alice',
        amount: 500,
        date: DateTime.now(),
        note: 'Paid back',
      );

      expect(settlement.type, LoanType.borrowed);
      expect(settlement.isSettlement, isTrue);
      expect(settlement.amount, 500);
    });

    test('settle negative balance creates lent settlement', () async {
      // We owe Bob 300 (borrowed)
      await repo.create(
        id: 'loan_borrowed', personId: 'per_bob', type: LoanType.borrowed,
        amount: 300, date: DateTime.now(),
      );

      final settlement = await repo.settle(
        personId: 'per_bob',
        amount: 300,
        date: DateTime.now(),
        note: 'Repaid',
      );

      expect(settlement.type, LoanType.lent);
      expect(settlement.isSettlement, isTrue);
    });

    test('deleted loans excluded from balance', () async {
      await repo.create(
        id: 'loan_active', personId: 'per_alice', type: LoanType.lent,
        amount: 500, date: DateTime.now(),
      );
      await repo.create(
        id: 'loan_deleted', personId: 'per_alice', type: LoanType.lent,
        amount: 200, date: DateTime.now(),
      );
      await repo.delete('loan_deleted');

      final balance = await repo.getPersonBalance('per_alice');
      expect(balance, 500.0); // Only active loan
    });
  });
}
