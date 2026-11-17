import 'package:sqflite/sqflite.dart';
import '../models/loan.dart';
import 'database_helper.dart';

class LocalLoanDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Loan loan) async {
    final db = await _db;
    return await db.insert(
      'loans',
      _toMap(loan),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Loan loan) async {
    final db = await _db;
    return await db.update(
      'loans',
      _toMap(loan),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'loans',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Loan?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Loan>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('loans', orderBy: 'date DESC');
    } else {
      maps = await db.query(
        'loans',
        where: 'deleted_at IS NULL',
        orderBy: 'date DESC',
      );
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Loan>> getByPersonId(
    String personId, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = 'person_id = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'loans',
      where: whereClause,
      whereArgs: [personId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<double> calculatePersonBalance(String personId) async {
    final db = await _db;
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
    final db = await _db;
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
      balances[row['person_id'] as String] = (row['balance'] as num).toDouble();
    }
    return balances;
  }

  Future<double> getTotalOwedToYou() async {
    final balances = await calculateAllBalances();
    return balances.values
        .where((b) => b > 0)
        .fold<double>(0.0, (sum, b) => sum + b);
  }

  Future<double> getTotalYouOwe() async {
    final balances = await calculateAllBalances();
    return balances.values
        .where((b) => b < 0)
        .fold<double>(0.0, (sum, b) => sum + b.abs());
  }

  Future<int> insertBatch(List<Loan> loans) async {
    final db = await _db;
    final batch = db.batch();
    for (final loan in loans) {
      batch.insert(
        'loans',
        _toMap(loan),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, 'loans', except);
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
