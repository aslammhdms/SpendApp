import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/test_database_helper.dart';

void main() {
  late Database db;

  setUpAll(() {
    initTestDatabase();
  });

  group('Database Default Data', () {
    setUp(() async {
      db = await createTestDatabase();
    });

    tearDown(() async {
      await closeTestDatabase(db);
    });

    test('fresh DB has 20 expense categories', () async {
      final rows = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: ['expense'],
      );
      expect(rows.length, equals(20));
    });

    test('fresh DB has 8 income categories', () async {
      final rows = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: ['income'],
      );
      expect(rows.length, equals(8));
    });

    test('fresh DB has 3 default accounts', () async {
      final rows = await db.query('accounts');
      expect(rows.length, equals(3));
    });

    test('category IDs match expected pattern', () async {
      final rows = await db.query('categories', columns: ['id']);
      final ids = rows.map((r) => r['id'] as String).toSet();

      // Spot-check key expense category IDs
      expect(ids, contains('cat_food'));
      expect(ids, contains('cat_grocery'));
      expect(ids, contains('cat_transport'));
      expect(ids, contains('cat_shopping'));
      expect(ids, contains('cat_other_expense'));

      // Spot-check key income category IDs
      expect(ids, contains('cat_salary'));
      expect(ids, contains('cat_freelance'));
      expect(ids, contains('cat_other_income'));
    });

    test('account IDs match expected pattern', () async {
      final rows = await db.query('accounts', columns: ['id']);
      final ids = rows.map((r) => r['id'] as String).toSet();

      expect(ids, contains('acc_cash'));
      expect(ids, contains('acc_bank'));
      expect(ids, contains('acc_credit'));
    });

    test('categories have correct types', () async {
      final food = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: ['cat_food'],
      );
      expect(food.first['type'], equals('expense'));

      final salary = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: ['cat_salary'],
      );
      expect(salary.first['type'], equals('income'));
    });

    test('accounts have initial_balance = 0.0 and currency = USD', () async {
      final rows = await db.query('accounts');
      for (final row in rows) {
        expect((row['initial_balance'] as num).toDouble(), equals(0.0));
        expect(row['currency'], equals('USD'));
      }
    });

    test('all categories have created_at and updated_at timestamps', () async {
      final rows = await db.query('categories');
      for (final row in rows) {
        expect(row['created_at'], isNotNull);
        expect(row['updated_at'], isNotNull);
        // Should be valid ISO8601
        expect(() => DateTime.parse(row['created_at'] as String), returnsNormally);
        expect(() => DateTime.parse(row['updated_at'] as String), returnsNormally);
      }
    });

    test('all accounts have created_at and updated_at timestamps', () async {
      final rows = await db.query('accounts');
      for (final row in rows) {
        expect(row['created_at'], isNotNull);
        expect(row['updated_at'], isNotNull);
        expect(() => DateTime.parse(row['created_at'] as String), returnsNormally);
        expect(() => DateTime.parse(row['updated_at'] as String), returnsNormally);
      }
    });
  });

  group('Database Migration v1 -> v2', () {
    test('empty v1 DB upgraded to v2 gets defaults populated', () async {
      db = await createEmptyTestDatabase();

      // Verify empty
      final catsBefore = await db.query('categories');
      final accsBefore = await db.query('accounts');
      expect(catsBefore, isEmpty);
      expect(accsBefore, isEmpty);

      // Simulate migration
      await simulateMigrationV1ToV2(db);

      // Verify populated
      final catsAfter = await db.query('categories');
      final accsAfter = await db.query('accounts');
      expect(catsAfter.length, equals(28));
      expect(accsAfter.length, equals(3));

      await closeTestDatabase(db);
    });

    test('DB with existing data is NOT overwritten by migration', () async {
      db = await createEmptyTestDatabase();

      // Insert custom data
      final now = DateTime.now().toIso8601String();
      await db.insert('categories', {
        'id': 'custom_cat',
        'name': 'My Custom Category',
        'type': 'expense',
        'icon': '🎯',
        'color': 0xFFFF0000,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('accounts', {
        'id': 'custom_acc',
        'name': 'My Custom Account',
        'type': 'cash',
        'initial_balance': 500.0,
        'currency': 'EUR',
        'icon': '💶',
        'color': 0xFF0000FF,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Simulate migration — should NOT overwrite
      await simulateMigrationV1ToV2(db);

      // Should still have only custom data
      final cats = await db.query('categories');
      expect(cats.length, equals(1));
      expect(cats.first['id'], equals('custom_cat'));

      final accs = await db.query('accounts');
      expect(accs.length, equals(1));
      expect(accs.first['id'], equals('custom_acc'));

      await closeTestDatabase(db);
    });
  });
}
