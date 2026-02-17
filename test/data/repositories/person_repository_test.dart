import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/person.dart';

import '../../helpers/test_database_helper.dart';
import '../../helpers/mock_sync_engine.dart';

/// Testable person repo using real in-memory DB + MockSyncEngine.
class _TestPersonRepo {
  final Database _db;
  final MockSyncEngine _syncEngine;

  _TestPersonRepo(this._db, this._syncEngine);

  Future<Person> create({
    required String id,
    required String name,
    String? phone,
    String? note,
  }) async {
    final now = DateTime.now();
    final person = Person(
      id: id,
      name: name,
      phone: phone,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('people', _toMap(person));
    await _syncEngine.queueOperation(
      entityType: 'person',
      entityId: person.id,
      operation: 'create',
      data: person.toJson(),
    );
    return person;
  }

  Future<List<Person>> getAll({bool includeDeleted = false}) async {
    final maps = includeDeleted
        ? await _db.query('people', orderBy: 'name ASC')
        : await _db.query('people',
            where: 'deleted_at IS NULL', orderBy: 'name ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<Person?> getById(String id) async {
    final maps =
        await _db.query('people', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<Person> update(Person person) async {
    final updated = person.copyWith(updatedAt: DateTime.now());
    await _db.update('people', _toMap(updated),
        where: 'id = ?', whereArgs: [updated.id]);
    await _syncEngine.queueOperation(
      entityType: 'person',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );
    return updated;
  }

  Future<void> delete(String id) async {
    final person = await getById(id);
    if (person == null) return;
    final deleted = person.copyWithDelete();
    await _db.update('people', _toMap(deleted),
        where: 'id = ?', whereArgs: [id]);
    await _syncEngine.queueOperation(
      entityType: 'person',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<List<Person>> search(String query) async {
    final maps = await _db.query('people',
        where: 'name LIKE ? AND deleted_at IS NULL',
        whereArgs: ['%$query%'],
        orderBy: 'name ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Map<String, dynamic> _toMap(Person p) => {
        'id': p.id,
        'name': p.name,
        'phone': p.phone,
        'note': p.note,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt.toIso8601String(),
        'deleted_at': p.deletedAt?.toIso8601String(),
      };

  Person _fromMap(Map<String, dynamic> map) => Person(
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

void main() {
  late Database db;
  late MockSyncEngine mockSyncEngine;
  late _TestPersonRepo repo;

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

    repo = _TestPersonRepo(db, mockSyncEngine);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('PersonRepository', () {
    test('create inserts and queues sync', () async {
      final person = await repo.create(
        id: 'per_1', name: 'Alice', phone: '555-1234',
      );

      expect(person.name, 'Alice');
      expect(person.phone, '555-1234');

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'person',
            entityId: 'per_1',
            operation: 'create',
            data: any(named: 'data'),
          )).called(1);
    });

    test('getAll excludes deleted', () async {
      await repo.create(id: 'per_1', name: 'Alice');
      await repo.create(id: 'per_2', name: 'Bob');
      await repo.delete('per_2');

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'Alice');
    });

    test('getById returns correct person', () async {
      await repo.create(id: 'per_test', name: 'Charlie', note: 'Friend');

      final p = await repo.getById('per_test');
      expect(p, isNotNull);
      expect(p!.name, 'Charlie');
      expect(p.note, 'Friend');
    });

    test('getById returns null for missing', () async {
      final p = await repo.getById('nonexistent');
      expect(p, isNull);
    });

    test('update modifies and queues sync', () async {
      final person = await repo.create(id: 'per_upd', name: 'Old Name');

      final updated =
          await repo.update(person.copyWith(name: 'New Name', phone: '555'));

      expect(updated.name, 'New Name');
      expect(updated.phone, '555');

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'person',
            entityId: 'per_upd',
            operation: 'update',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete soft-deletes and queues sync', () async {
      await repo.create(id: 'per_del', name: 'Delete Me');

      await repo.delete('per_del');

      final p = await repo.getById('per_del');
      expect(p!.deletedAt, isNotNull);

      verify(() => mockSyncEngine.queueOperation(
            entityType: 'person',
            entityId: 'per_del',
            operation: 'delete',
            data: any(named: 'data'),
          )).called(1);
    });

    test('delete non-existent is no-op', () async {
      await repo.delete('nonexistent');
      verifyNever(() => mockSyncEngine.queueOperation(
            entityType: 'person',
            entityId: 'nonexistent',
            operation: any(named: 'operation'),
            data: any(named: 'data'),
          ));
    });

    test('search finds partial match', () async {
      await repo.create(id: 'per_1', name: 'Alice Smith');
      await repo.create(id: 'per_2', name: 'Bob Jones');
      await repo.create(id: 'per_3', name: 'Alice Wonder');

      final results = await repo.search('Alice');
      expect(results.length, 2);
    });

    test('search excludes deleted', () async {
      await repo.create(id: 'per_1', name: 'Alice Active');
      await repo.create(id: 'per_2', name: 'Alice Deleted');
      await repo.delete('per_2');

      final results = await repo.search('Alice');
      expect(results.length, 1);
      expect(results.first.name, 'Alice Active');
    });
  });
}
