import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/local/database_helper.dart';

import '../../helpers/test_database_helper.dart';

void main() {
  late Database db;

  setUpAll(initTestDatabase);

  setUp(() async {
    db = await createEmptyTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  Future<void> insertPeople(int count) async {
    final now = DateTime(2026, 11, 1).toIso8601String();
    final batch = db.batch();
    for (var i = 0; i < count; i++) {
      batch.insert('people', {
        'id': 'p$i',
        'name': 'Person $i',
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<Set<String>> remainingIds() async {
    final rows = await db.query('people', columns: ['id']);
    return {for (final row in rows) row['id'] as String};
  }

  group('DatabaseHelper.deleteAllExcept', () {
    test('keeps only the listed rows, across more rows than one chunk',
        () async {
      await insertPeople(1200);

      final deleted =
          await DatabaseHelper.deleteAllExcept(db, 'people', {'p7', 'p1100'});

      expect(deleted, 1198);
      expect(await remainingIds(), {'p7', 'p1100'});
    });

    test('clears the table when nothing is kept', () async {
      await insertPeople(3);

      await DatabaseHelper.deleteAllExcept(db, 'people', {});

      expect(await remainingIds(), isEmpty);
    });

    test('ignores kept IDs that are not in the table', () async {
      await insertPeople(2);

      await DatabaseHelper.deleteAllExcept(db, 'people', {'p1', 'nobody'});

      expect(await remainingIds(), {'p1'});
    });
  });
}
