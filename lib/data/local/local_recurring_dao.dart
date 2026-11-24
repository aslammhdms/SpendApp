import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import 'database_helper.dart';

/// Repeating payments (rent, subscriptions, salary) on this device.
class LocalRecurringDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  static const _table = 'recurring_rules';

  Future<int> insert(RecurringRule rule) async {
    final db = await _db;
    return db.insert(
      _table,
      toMap(rule),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(RecurringRule rule) async {
    final db = await _db;
    return db.update(
      _table,
      toMap(rule),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<RecurringRule?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : fromMap(maps.first);
  }

  /// Live rules, soonest due first.
  Future<List<RecurringRule>> getAll() async {
    final db = await _db;
    final maps = await db.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'next_due_date ASC',
    );
    return maps.map(fromMap).toList();
  }

  Future<int> insertBatch(List<RecurringRule> rules) async {
    final db = await _db;
    final batch = db.batch();
    for (final rule in rules) {
      batch.insert(
        _table,
        toMap(rule),
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

  static Map<String, dynamic> toMap(RecurringRule rule) {
    return {
      'id': rule.id,
      'name': rule.name,
      'amount': rule.amount,
      'type': rule.type.name,
      'category_id': rule.categoryId,
      'account_id': rule.accountId,
      'frequency': rule.frequency.name,
      'interval_value': rule.interval,
      'next_due_date': rule.nextDueDate.toIso8601String(),
      'end_date': rule.endDate?.toIso8601String(),
      'note': rule.note,
      'is_active': rule.isActive ? 1 : 0,
      'created_at': rule.createdAt.toIso8601String(),
      'updated_at': rule.updatedAt.toIso8601String(),
      'deleted_at': rule.deletedAt?.toIso8601String(),
    };
  }

  static RecurringRule fromMap(Map<String, dynamic> map) {
    return RecurringRule(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: map['category_id'] as String,
      accountId: map['account_id'] as String,
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      interval: (map['interval_value'] as num?)?.toInt() ?? 1,
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      note: map['note'] as String?,
      isActive: (map['is_active'] as num?) != 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}
