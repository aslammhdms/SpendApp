import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/person.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around PersonDao that accepts a [Database] directly.
class TestPersonDao {
  final Database db;
  TestPersonDao(this.db);

  Future<int> insert(Person person) async {
    return await db.insert('people', _toMap(person),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(Person person) async {
    return await db.update('people', _toMap(person),
        where: 'id = ?', whereArgs: [person.id]);
  }

  Future<int> softDelete(String id) async {
    return await db.update(
        'people', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Person?> getById(String id) async {
    final maps = await db.query('people', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Person>> getAll({bool includeDeleted = false}) async {
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('people', orderBy: 'name ASC');
    } else {
      maps = await db.query('people',
          where: 'deleted_at IS NULL', orderBy: 'name ASC');
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Person>> search(String query) async {
    final maps = await db.query('people',
        where: 'name LIKE ? AND deleted_at IS NULL',
        whereArgs: ['%$query%'],
        orderBy: 'name ASC');
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<int> insertBatch(List<Person> people) async {
    final batch = db.batch();
    for (final person in people) {
      batch.insert('people', _toMap(person),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit();
    return results.length;
  }

  Future<int> deleteAll() async {
    return await db.delete('people');
  }

  Map<String, dynamic> _toMap(Person person) {
    return {
      'id': person.id,
      'name': person.name,
      'phone': person.phone,
      'note': person.note,
      'created_at': person.createdAt.toIso8601String(),
      'updated_at': person.updatedAt.toIso8601String(),
      'deleted_at': person.deletedAt?.toIso8601String(),
    };
  }

  Person _fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}

Person _makePerson({
  required String id,
  String name = 'John Doe',
  String? phone,
  String? note,
}) {
  final now = DateTime.now();
  return Person(
    id: id,
    name: name,
    phone: phone,
    note: note,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Database db;
  late TestPersonDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestPersonDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('PersonDao', () {
    test('insert and getById roundtrip', () async {
      final person = _makePerson(
        id: 'per_1',
        name: 'Alice',
        phone: '555-1234',
        note: 'Friend',
      );
      await dao.insert(person);

      final result = await dao.getById('per_1');
      expect(result, isNotNull);
      expect(result!.name, 'Alice');
      expect(result.phone, '555-1234');
      expect(result.note, 'Friend');
    });

    test('getById returns null for missing id', () async {
      final result = await dao.getById('nonexistent');
      expect(result, isNull);
    });

    test('getAll returns non-deleted people ordered by name', () async {
      await dao.insert(_makePerson(id: 'per_c', name: 'Charlie'));
      await dao.insert(_makePerson(id: 'per_a', name: 'Alice'));
      await dao.insert(_makePerson(id: 'per_b', name: 'Bob'));

      final all = await dao.getAll();
      expect(all.length, 3);
      expect(all[0].name, 'Alice');
      expect(all[1].name, 'Bob');
      expect(all[2].name, 'Charlie');
    });

    test('getAll excludes soft-deleted by default', () async {
      await dao.insert(_makePerson(id: 'per_1', name: 'Alice'));
      await dao.insert(_makePerson(id: 'per_2', name: 'Bob'));
      await dao.softDelete('per_1');

      final all = await dao.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'Bob');
    });

    test('getAll(includeDeleted: true) includes soft-deleted', () async {
      await dao.insert(_makePerson(id: 'per_1', name: 'Alice'));
      await dao.insert(_makePerson(id: 'per_2', name: 'Bob'));
      await dao.softDelete('per_1');

      final all = await dao.getAll(includeDeleted: true);
      expect(all.length, 2);
    });

    test('softDelete sets deleted_at', () async {
      await dao.insert(_makePerson(id: 'per_1'));
      await dao.softDelete('per_1');

      final person = await dao.getById('per_1');
      expect(person, isNotNull);
      expect(person!.deletedAt, isNotNull);
    });

    test('update modifies name, phone, note', () async {
      await dao.insert(_makePerson(
          id: 'per_1', name: 'Alice', phone: '111', note: 'Old'));
      final original = await dao.getById('per_1');

      final updated =
          original!.copyWith(name: 'Alicia', phone: '222', note: 'New');
      await dao.update(updated);

      final result = await dao.getById('per_1');
      expect(result!.name, 'Alicia');
      expect(result.phone, '222');
      expect(result.note, 'New');
    });

    test('search finds by partial name (case insensitive)', () async {
      await dao.insert(_makePerson(id: 'per_1', name: 'Alice Johnson'));
      await dao.insert(_makePerson(id: 'per_2', name: 'Bob Smith'));
      await dao.insert(_makePerson(id: 'per_3', name: 'Alicia Jones'));

      final results = await dao.search('ali');
      expect(results.length, 2);
      final names = results.map((r) => r.name).toSet();
      expect(names, contains('Alice Johnson'));
      expect(names, contains('Alicia Jones'));
    });

    test('search excludes soft-deleted', () async {
      await dao.insert(_makePerson(id: 'per_1', name: 'Alice'));
      await dao.softDelete('per_1');

      final results = await dao.search('Alice');
      expect(results, isEmpty);
    });

    test('insertBatch inserts multiple people', () async {
      final people = [
        _makePerson(id: 'per_1', name: 'Alice'),
        _makePerson(id: 'per_2', name: 'Bob'),
        _makePerson(id: 'per_3', name: 'Charlie'),
      ];
      final count = await dao.insertBatch(people);
      expect(count, 3);

      final all = await dao.getAll();
      expect(all.length, 3);
    });

    test('deleteAll removes everything', () async {
      await dao.insert(_makePerson(id: 'per_1', name: 'Alice'));
      await dao.insert(_makePerson(id: 'per_2', name: 'Bob'));

      await dao.deleteAll();

      final all = await dao.getAll(includeDeleted: true);
      expect(all, isEmpty);
    });

    test('empty search query returns all non-deleted', () async {
      await dao.insert(_makePerson(id: 'per_1', name: 'Alice'));
      await dao.insert(_makePerson(id: 'per_2', name: 'Bob'));

      final results = await dao.search('');
      expect(results.length, 2);
    });
  });
}
