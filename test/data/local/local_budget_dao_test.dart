import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/budget.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around BudgetDao that accepts a [Database] directly.
class TestBudgetDao {
  final Database db;
  TestBudgetDao(this.db);

  Future<int> insertBatch(List<Budget> budgets) async {
    final batch = db.batch();
    for (final budget in budgets) {
      batch.insert('budgets', _toMap(budget),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit();
    return results.length;
  }

  Future<int> deleteAll() async {
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

Budget _makeBudget({
  required String id,
  String name = 'Test Budget',
  double amount = 500.0,
  BudgetPeriod period = BudgetPeriod.monthly,
  String? categoryId = 'cat_food',
}) {
  final now = DateTime.now();
  return Budget(
    id: id,
    name: name,
    amount: amount,
    period: period,
    categoryId: categoryId,
    startDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Database db;
  late TestBudgetDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestBudgetDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('BudgetDao', () {
    test('insertBatch persists budgets with correct fields', () async {
      final budgets = [
        _makeBudget(id: 'bud_1', name: 'Food', amount: 500),
        _makeBudget(
          id: 'bud_2',
          name: 'Overall',
          amount: 2000,
          categoryId: null,
          period: BudgetPeriod.yearly,
        ),
      ];
      final count = await dao.insertBatch(budgets);
      expect(count, 2);

      // Verify fields directly from DB
      final rows = await db.query('budgets', orderBy: 'id ASC');
      expect(rows.length, 2);

      expect(rows[0]['id'], 'bud_1');
      expect(rows[0]['name'], 'Food');
      expect(rows[0]['amount'], 500.0);
      expect(rows[0]['period'], 'monthly');
      expect(rows[0]['category_id'], 'cat_food');

      expect(rows[1]['id'], 'bud_2');
      expect(rows[1]['category_id'], isNull);
      expect(rows[1]['period'], 'yearly');
    });

    test('insertBatch with conflict replace updates existing', () async {
      await dao.insertBatch([
        _makeBudget(id: 'bud_1', name: 'Old Name', amount: 500),
      ]);

      await dao.insertBatch([
        _makeBudget(id: 'bud_1', name: 'New Name', amount: 1000),
      ]);

      final rows = await db.query('budgets');
      expect(rows.length, 1);
      expect(rows[0]['name'], 'New Name');
      expect(rows[0]['amount'], 1000.0);
    });

    test('deleteAll clears table', () async {
      await dao.insertBatch([
        _makeBudget(id: 'bud_1'),
        _makeBudget(id: 'bud_2'),
        _makeBudget(id: 'bud_3'),
      ]);

      final deleted = await dao.deleteAll();
      expect(deleted, 3);

      final rows = await db.query('budgets');
      expect(rows, isEmpty);
    });

    test('insertBatch does NOT persist spentAmount', () async {
      final budget = Budget(
        id: 'bud_1',
        name: 'Test',
        amount: 500,
        period: BudgetPeriod.monthly,
        categoryId: 'cat_food',
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        spentAmount: 200, // This should NOT be in DB
      );
      await dao.insertBatch([budget]);

      final rows = await db.query('budgets');
      // The budgets table has no spentAmount column
      expect(rows[0].containsKey('spent_amount'), isFalse);
    });

    test('period stored as string', () async {
      await dao.insertBatch([
        _makeBudget(id: 'bud_w', period: BudgetPeriod.weekly),
        _makeBudget(id: 'bud_m', period: BudgetPeriod.monthly),
        _makeBudget(id: 'bud_y', period: BudgetPeriod.yearly),
      ]);

      final rows = await db.query('budgets', orderBy: 'id ASC');
      // IDs sort: bud_m < bud_w < bud_y
      expect(rows[0]['period'], 'monthly');
      expect(rows[1]['period'], 'weekly');
      expect(rows[2]['period'], 'yearly');
    });

    test('empty list insertBatch produces no error', () async {
      final count = await dao.insertBatch([]);
      expect(count, 0);
    });

    test('categoryId nullable stored correctly', () async {
      await dao.insertBatch([
        _makeBudget(id: 'bud_cat', categoryId: 'cat_food'),
        _makeBudget(id: 'bud_overall', categoryId: null),
      ]);

      final rows = await db.query('budgets', orderBy: 'id ASC');
      expect(rows[0]['category_id'], 'cat_food');
      expect(rows[1]['category_id'], isNull);
    });
  });
}
