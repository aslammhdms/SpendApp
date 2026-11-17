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

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, 'budgets', except);
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
