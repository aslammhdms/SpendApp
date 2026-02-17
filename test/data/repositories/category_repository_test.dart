import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/category.dart';

import '../../helpers/test_database_helper.dart';
import '../../helpers/mock_sync_engine.dart';

/// Testable category repo using real in-memory DB + MockSyncEngine.
class _TestCategoryRepo {
  final Database _db;
  final MockSyncEngine _syncEngine;

  _TestCategoryRepo(this._db, this._syncEngine);

  Future<List<Category>> getAll() async {
    final maps = await _db.query('categories',
        where: 'deleted_at IS NULL', orderBy: 'sort_order ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<Category?> getById(String id) async {
    final maps =
        await _db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Category>> getExpenseCategories() async {
    final maps = await _db.query('categories',
        where: 'type = ? AND deleted_at IS NULL',
        whereArgs: ['expense'],
        orderBy: 'sort_order ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<List<Category>> getIncomeCategories() async {
    final maps = await _db.query('categories',
        where: 'type = ? AND deleted_at IS NULL',
        whereArgs: ['income'],
        orderBy: 'sort_order ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<Category> create({
    required String id,
    required String name,
    required CategoryType type,
    String icon = '📝',
    int color = 0xFF808080,
  }) async {
    final now = DateTime.now();
    // Get next sort order
    final result = await _db.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) + 1 as next FROM categories WHERE type = ?',
        [type.name]);
    final sortOrder = (result.first['next'] as num).toInt();

    final category = Category(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('categories', _toMap(category));
    await _syncEngine.queueOperation(
      entityType: 'category',
      entityId: category.id,
      operation: 'create',
      data: category.toJson(),
    );
    return category;
  }

  Future<Category> update(Category category) async {
    final updated = category.copyWith(updatedAt: DateTime.now());
    await _db.update('categories', _toMap(updated),
        where: 'id = ?', whereArgs: [updated.id]);
    await _syncEngine.queueOperation(
      entityType: 'category',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );
    return updated;
  }

  Future<void> delete(String id) async {
    final category = await getById(id);
    if (category == null) return;
    final deleted = category.copyWithDelete();
    await _db.update('categories', _toMap(deleted),
        where: 'id = ?', whereArgs: [id]);
    await _syncEngine.queueOperation(
      entityType: 'category',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<void> reorder(List<Category> categories) async {
    for (int i = 0; i < categories.length; i++) {
      await _db.update('categories', {'sort_order': i},
          where: 'id = ?', whereArgs: [categories[i].id]);
    }
    for (final category in categories) {
      await _syncEngine.queueOperation(
        entityType: 'category',
        entityId: category.id,
        operation: 'update',
        data: category.toJson(),
      );
    }
  }

  Map<String, dynamic> _toMap(Category c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type.name,
        'icon': c.icon,
        'color': c.color,
        'sort_order': c.sortOrder,
        'created_at': c.createdAt.toIso8601String(),
        'updated_at': c.updatedAt.toIso8601String(),
        'deleted_at': c.deletedAt?.toIso8601String(),
      };

  Category _fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        type: CategoryType.values.firstWhere((e) => e.name == map['type'],
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

void main() {
  late Database db;
  late MockSyncEngine mockSyncEngine;
  late _TestCategoryRepo repo;

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

    repo = _TestCategoryRepo(db, mockSyncEngine);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('CategoryRepository', () {
    test('getAll returns default categories', () async {
      final all = await repo.getAll();
      // 28 defaults: 20 expense + 8 income
      expect(all.length, 28);
    });

    test('getExpenseCategories returns only expense type', () async {
      final expense = await repo.getExpenseCategories();
      expect(expense.length, 20);
      for (final c in expense) {
        expect(c.type, CategoryType.expense);
      }
    });

    test('getIncomeCategories returns only income type', () async {
      final income = await repo.getIncomeCategories();
      expect(income.length, 8);
      for (final c in income) {
        expect(c.type, CategoryType.income);
      }
    });

    test('create inserts with auto sort order and queues sync', () async {
      final cat = await repo.create(
        id: 'cat_custom',
        name: 'Custom',
        type: CategoryType.expense,
        icon: '🎯',
        color: 0xFFFF0000,
      );

      expect(cat.name, 'Custom');
      expect(cat.sortOrder, 20); // After 20 existing expense categories

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'category',
            entityId: 'cat_custom',
            operation: 'create',
            data: any(named: 'data'),
          )).called(1);
    });

    test('update modifies and queues sync', () async {
      final cat = await repo.getById('cat_food');
      expect(cat, isNotNull);

      final updated = await repo.update(cat!.copyWith(name: 'Food Updated'));
      expect(updated.name, 'Food Updated');

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'category',
            entityId: 'cat_food',
            operation: 'update',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete soft-deletes and queues sync', () async {
      await repo.delete('cat_food');

      final cat = await repo.getById('cat_food');
      expect(cat!.deletedAt, isNotNull);

      // Should not appear in getAll
      final all = await repo.getAll();
      expect(all.where((c) => c.id == 'cat_food'), isEmpty);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'category',
            entityId: 'cat_food',
            operation: 'delete',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete non-existent is no-op', () async {
      await repo.delete('nonexistent');
      verifyNever(() => mockSyncEngine.queueOperation(
            entityType: 'category',
            entityId: 'nonexistent',
            operation: any(named: 'operation'),
            data: any(named: 'data'),
          ));
    });

    test('reorder queues sync for each category', () async {
      final expense = await repo.getExpenseCategories();
      final first3 = expense.take(3).toList();
      final reversed = first3.reversed.toList();

      await repo.reorder(reversed);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'category',
            entityId: any(named: 'entityId'),
            operation: 'update',
            data: any(named: 'data'),
          )).called(3);
    });
  });
}
