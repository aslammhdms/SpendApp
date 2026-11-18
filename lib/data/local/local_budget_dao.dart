import 'package:sqflite/sqflite.dart';
import '../models/budget.dart';
import 'database_helper.dart';

class LocalBudgetDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insertBatch(List<Budget> budgets) async {
    final db = await _db;
    final batch = db.batch();
    for (final budget in budgets) {
      batch.insert(
        'budgets',
        _toMap(budget),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  /// IDs of the categories that live budgets track.
  Future<Set<String>> getUsedCategoryIds() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category_id FROM budgets '
      'WHERE deleted_at IS NULL AND category_id IS NOT NULL',
    );
    return rows.map((row) => row['category_id'] as String).toSet();
  }

  /// Live budgets that track [categoryId].
  Future<List<Budget>> getByCategory(String categoryId) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'category_id = ? AND deleted_at IS NULL',
      whereArgs: [categoryId],
    );
    return maps.map(_fromMap).toList();
  }

  Future<int> update(Budget budget) async {
    final db = await _db;
    return db.update(
      'budgets',
      _toMap(budget),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, 'budgets', except);
  }

  Budget _fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (e) => e.name == map['period'],
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryId: map['category_id'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _toMap(Budget budget) {
    return {
      'id': budget.id,
      'name': budget.name,
      'amount': budget.amount,
      'period': budget.period.name,
      'category_id': budget.categoryId,
      'start_date': budget.startDate.toIso8601String(),
      'created_at': budget.createdAt.toIso8601String(),
      'updated_at': budget.updatedAt.toIso8601String(),
      'deleted_at': budget.deletedAt?.toIso8601String(),
    };
  }
}
