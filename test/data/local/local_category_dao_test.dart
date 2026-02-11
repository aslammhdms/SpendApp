import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/category.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around category DAO logic that accepts a [Database]
/// parameter instead of using the DatabaseHelper singleton.
class TestCategoryDao {
  final Database db;
  TestCategoryDao(this.db);

  Future<int> insert(Category category) async {
    return await db.insert('categories', _toMap(category),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(Category category) async {
    return await db.update('categories', _toMap(category),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> softDelete(String id) async {
    return await db.update('categories',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Category?> getById(String id) async {
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Category>> getAll({bool includeDeleted = false}) async {
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('categories', orderBy: 'sort_order ASC');
    } else {
      maps = await db.query('categories',
          where: 'deleted_at IS NULL', orderBy: 'sort_order ASC');
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Category>> getByType(CategoryType type,
      {bool includeDeleted = false}) async {
    String whereClause = 'type = ?';
    if (!includeDeleted) {
      whereClause += ' AND deleted_at IS NULL';
    }
    final maps = await db.query('categories',
        where: whereClause, whereArgs: [type.name], orderBy: 'sort_order ASC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Category>> getExpenseCategories(
          {bool includeDeleted = false}) =>
      getByType(CategoryType.expense, includeDeleted: includeDeleted);

  Future<List<Category>> getIncomeCategories(
          {bool includeDeleted = false}) =>
      getByType(CategoryType.income, includeDeleted: includeDeleted);

  Future<int> getNextSortOrder(CategoryType type) async {
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order
      FROM categories WHERE type = ?
    ''', [type.name]);
    return (result.first['next_order'] as num).toInt();
  }

  Future<int> deleteAll() async {
    return await db.delete('categories');
  }

  Future<int> insertBatch(List<Category> categories) async {
    final batch = db.batch();
    for (final category in categories) {
      batch.insert('categories', _toMap(category),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit();
    return results.length;
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
      type: CategoryType.values
          .firstWhere((e) => e.name == map['type'],
              orElse: () => CategoryType.expense),
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

void main() {
  late Database db;
  late TestCategoryDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestCategoryDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('CategoryDao', () {
    test('getAll returns default categories', () async {
      final categories = await dao.getAll();
      expect(categories.length, equals(28));
    });

    test('getByType(expense) returns 20 expense categories', () async {
      final expenses = await dao.getByType(CategoryType.expense);
      expect(expenses.length, equals(20));
      for (final cat in expenses) {
        expect(cat.type, equals(CategoryType.expense));
      }
    });

    test('getByType(income) returns 8 income categories', () async {
      final incomes = await dao.getByType(CategoryType.income);
      expect(incomes.length, equals(8));
      for (final cat in incomes) {
        expect(cat.type, equals(CategoryType.income));
      }
    });

    test('getExpenseCategories shortcut works', () async {
      final expenses = await dao.getExpenseCategories();
      expect(expenses.length, equals(20));
    });

    test('getIncomeCategories shortcut works', () async {
      final incomes = await dao.getIncomeCategories();
      expect(incomes.length, equals(8));
    });

    test('insert adds a new category', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'cat_test',
        name: 'Test Category',
        type: CategoryType.expense,
        icon: '🧪',
        color: 0xFFFF0000,
        sortOrder: 100,
        createdAt: now,
        updatedAt: now,
      );

      await dao.insert(category);

      final result = await dao.getById('cat_test');
      expect(result, isNotNull);
      expect(result!.name, equals('Test Category'));
      expect(result.icon, equals('🧪'));
    });

    test('update modifies existing category', () async {
      final original = await dao.getById('cat_food');
      expect(original, isNotNull);

      final updated = original!.copyWith(name: 'Updated Food');
      await dao.update(updated);

      final result = await dao.getById('cat_food');
      expect(result!.name, equals('Updated Food'));
    });

    test('softDelete sets deleted_at', () async {
      await dao.softDelete('cat_food');

      final result = await dao.getById('cat_food');
      expect(result, isNotNull);
      expect(result!.deletedAt, isNotNull);
    });

    test('getAll(includeDeleted: false) excludes soft-deleted', () async {
      final beforeCount = (await dao.getAll()).length;
      await dao.softDelete('cat_food');

      final afterAll = await dao.getAll(includeDeleted: false);
      expect(afterAll.length, equals(beforeCount - 1));
      expect(afterAll.any((c) => c.id == 'cat_food'), isFalse);
    });

    test('getAll(includeDeleted: true) includes soft-deleted', () async {
      await dao.softDelete('cat_food');

      final all = await dao.getAll(includeDeleted: true);
      expect(all.any((c) => c.id == 'cat_food'), isTrue);
    });

    test('getById returns correct category', () async {
      final result = await dao.getById('cat_salary');
      expect(result, isNotNull);
      expect(result!.name, equals('Salary'));
      expect(result.type, equals(CategoryType.income));
    });

    test('getById returns null for missing ID', () async {
      final result = await dao.getById('nonexistent');
      expect(result, isNull);
    });

    test('getNextSortOrder returns max+1', () async {
      final next = await dao.getNextSortOrder(CategoryType.expense);
      // 20 expense categories with sort_order 0..19, so next should be 20
      expect(next, equals(20));
    });

    test('deleteAll removes everything', () async {
      await dao.deleteAll();
      final all = await dao.getAll(includeDeleted: true);
      expect(all, isEmpty);
    });

    test('insertBatch works correctly', () async {
      await dao.deleteAll();
      final now = DateTime.now();
      final categories = List.generate(
        5,
        (i) => Category(
          id: 'batch_$i',
          name: 'Batch $i',
          type: CategoryType.expense,
          icon: '📦',
          color: 0xFF000000 + i,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final count = await dao.insertBatch(categories);
      expect(count, equals(5));

      final all = await dao.getAll();
      expect(all.length, equals(5));
    });
  });
}
