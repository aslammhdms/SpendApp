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

  Future<int> deleteAll() async {
    final db = await _db;
    return await db.delete('budgets');
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
