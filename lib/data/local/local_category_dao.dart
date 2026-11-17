import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import 'database_helper.dart';

class LocalCategoryDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Category category) async {
    final db = await _db;
    return await db.insert(
      'categories',
      _toMap(category),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Category category) async {
    final db = await _db;
    return await db.update(
      'categories',
      _toMap(category),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'categories',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Category?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Category>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('categories', orderBy: 'sort_order ASC');
    } else {
      maps = await db.query(
        'categories',
        where: 'deleted_at IS NULL',
        orderBy: 'sort_order ASC',
      );
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Category>> getByType(
    CategoryType type, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    String whereClause = 'type = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query(
      'categories',
      where: whereClause,
      whereArgs: [type.name],
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Category>> getExpenseCategories({bool includeDeleted = false}) {
    return getByType(CategoryType.expense, includeDeleted: includeDeleted);
  }

  Future<List<Category>> getIncomeCategories({bool includeDeleted = false}) {
    return getByType(CategoryType.income, includeDeleted: includeDeleted);
  }

  Future<int> getNextSortOrder(CategoryType type) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order
      FROM categories
      WHERE type = ?
    ''', [type.name]);
    return (result.first['next_order'] as num).toInt();
  }

  Future<void> updateSortOrders(List<Category> categories) async {
    final db = await _db;
    final batch = db.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update(
        'categories',
        {
          'sort_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [categories[i].id],
      );
    }
    await batch.commit();
  }

  Future<int> insertBatch(List<Category> categories) async {
    final db = await _db;
    final batch = db.batch();
    for (final category in categories) {
      batch.insert(
        'categories',
        _toMap(category),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  /// Deletes every row, except those whose ID is in [except].
  Future<int> deleteAll({Set<String> except = const {}}) async {
    final db = await _db;
    return DatabaseHelper.deleteAllExcept(db, 'categories', except);
  }

  Map<String, dynamic> _toMap(Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'type': category.type.name,
      'icon': category.icon,
      'color': category.color,
      'sort_order': category.sortOrder,
      'created_at': category.createdAt.toIso8601String(),
      'updated_at': category.updatedAt.toIso8601String(),
      'deleted_at': category.deletedAt?.toIso8601String(),
    };
  }

  Category _fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      type: CategoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CategoryType.expense,
      ),
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
