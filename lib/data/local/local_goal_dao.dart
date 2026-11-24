import 'package:sqflite/sqflite.dart';
import '../models/goal.dart';
import 'database_helper.dart';

/// Savings goals on this device.
class LocalGoalDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  static const _table = 'goals';

  Future<int> insert(Goal goal) async {
    final db = await _db;
    return db.insert(
      _table,
      toMap(goal),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Goal goal) async {
    final db = await _db;
    return db.update(
      _table,
      toMap(goal),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<Goal?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : fromMap(maps.first);
  }

  /// Live goals, oldest first.
  Future<List<Goal>> getAll() async {
    final db = await _db;
    final maps = await db.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return maps.map(fromMap).toList();
  }

  Future<int> insertBatch(List<Goal> goals) async {
    final db = await _db;
    final batch = db.batch();
    for (final goal in goals) {
      batch.insert(
        _table,
        toMap(goal),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, _table, except);
  }

  static Map<String, dynamic> toMap(Goal goal) {
    return {
      'id': goal.id,
      'name': goal.name,
      'target_amount': goal.targetAmount,
      'saved_amount': goal.savedAmount,
      'target_date': goal.targetDate?.toIso8601String(),
      'icon': goal.icon,
      'color': goal.color,
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': goal.updatedAt.toIso8601String(),
      'deleted_at': goal.deletedAt?.toIso8601String(),
    };
  }

  static Goal fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num?)?.toDouble() ?? 0,
      targetDate: map['target_date'] != null
          ? DateTime.parse(map['target_date'] as String)
          : null,
      icon: map['icon'] as String,
      color: (map['color'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}
