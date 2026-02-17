import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spendsheet/data/models/app_settings.dart';

import '../../helpers/test_database_helper.dart';

/// Thin test wrapper around SyncQueueDao that accepts a [Database] directly.
class TestSyncQueueDao {
  final Database db;
  TestSyncQueueDao(this.db);

  Future<int> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final existing = await db.query('sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId]);

    if (existing.isNotEmpty) {
      return await db.update(
        'sync_queue',
        {
          'operation': operation,
          'data': jsonEncode(data),
          'created_at': DateTime.now().toIso8601String(),
          'retry_count': 0,
          'error_message': null,
        },
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );
    }

    return await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  Future<List<SyncQueueItem>> getPending({int limit = 50}) async {
    final maps = await db.query('sync_queue',
        where: 'retry_count < 3', orderBy: 'created_at ASC', limit: limit);
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<int> getPendingCount() async {
    final result = await db
        .rawQuery('SELECT COUNT(*) as count FROM sync_queue WHERE retry_count < 3');
    return (result.first['count'] as num).toInt();
  }

  Future<int> getCount() async {
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    return (result.first['count'] as num).toInt();
  }

  Future<List<SyncQueueItem>> getAll() async {
    final maps = await db.query('sync_queue', orderBy: 'created_at ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<List<SyncQueueItem>> getByEntityType(String entityType) async {
    final maps = await db.query('sync_queue',
        where: 'entity_type = ?',
        whereArgs: [entityType],
        orderBy: 'created_at ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  Future<int> delete(int id) async {
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByEntity(String entityType, String entityId) async {
    return await db.delete('sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId]);
  }

  Future<int> incrementRetryCount(int id, {String? errorMessage}) async {
    return await db.rawUpdate('''
      UPDATE sync_queue
      SET retry_count = retry_count + 1,
          error_message = ?
      WHERE id = ?
    ''', [errorMessage, id]);
  }

  Future<int> resetFailedItems(List<String> entityTypes) async {
    if (entityTypes.isEmpty) return 0;
    final placeholders = entityTypes.map((_) => '?').join(', ');
    return await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = 0, error_message = NULL '
      'WHERE entity_type IN ($placeholders) AND retry_count >= 3',
      entityTypes,
    );
  }

  Future<int> deleteCompleted() async {
    return await db.delete('sync_queue', where: 'retry_count >= 3');
  }

  Future<int> deleteAll() async {
    return await db.delete('sync_queue');
  }

  SyncQueueItem _fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: map['operation'] as String,
      data: map['data'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int,
      errorMessage: map['error_message'] as String?,
    );
  }
}

void main() {
  late Database db;
  late TestSyncQueueDao dao;

  setUpAll(() {
    initTestDatabase();
  });

  setUp(() async {
    db = await createTestDatabase();
    dao = TestSyncQueueDao(db);
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  group('SyncQueueDao', () {
    test('enqueue creates new entry', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1', 'amount': 100},
      );

      final all = await dao.getAll();
      expect(all.length, 1);
      expect(all.first.entityType, 'transaction');
      expect(all.first.entityId, 'txn_1');
      expect(all.first.operation, 'create');
      expect(all.first.retryCount, 0);
    });

    test('enqueue same entity twice updates existing and resets retry_count',
        () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );

      // Simulate a failed retry
      final items = await dao.getAll();
      await dao.incrementRetryCount(items.first.id, errorMessage: 'Error');

      // Re-enqueue same entity
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'update',
        data: {'id': 'txn_1', 'amount': 200},
      );

      final all = await dao.getAll();
      expect(all.length, 1);
      expect(all.first.operation, 'update');
      expect(all.first.retryCount, 0); // Reset!
    });

    test('enqueue different entities creates separate entries', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'account',
        entityId: 'acc_1',
        operation: 'create',
        data: {'id': 'acc_1'},
      );

      final all = await dao.getAll();
      expect(all.length, 2);
    });

    test('getPending returns items with retry_count < 3 ordered by created_at',
        () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_2',
        operation: 'create',
        data: {'id': 'txn_2'},
      );

      final pending = await dao.getPending();
      expect(pending.length, 2);
      // Should be ordered by created_at ASC
      expect(pending[0].entityId, 'txn_1');
      expect(pending[1].entityId, 'txn_2');
    });

    test('getPending respects limit parameter', () async {
      for (int i = 0; i < 5; i++) {
        await dao.enqueue(
          entityType: 'transaction',
          entityId: 'txn_$i',
          operation: 'create',
          data: {'id': 'txn_$i'},
        );
      }

      final pending = await dao.getPending(limit: 2);
      expect(pending.length, 2);
    });

    test('getPending excludes failed items (retry_count >= 3)', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );

      final items = await dao.getAll();
      // Fail it 3 times
      for (int i = 0; i < 3; i++) {
        await dao.incrementRetryCount(items.first.id);
      }

      final pending = await dao.getPending();
      expect(pending, isEmpty);
    });

    test('getPendingCount matches getPending length', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'account',
        entityId: 'acc_1',
        operation: 'create',
        data: {'id': 'acc_1'},
      );

      final count = await dao.getPendingCount();
      final pending = await dao.getPending();
      expect(count, pending.length);
      expect(count, 2);
    });

    test('getCount returns total including failed', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );

      final items = await dao.getAll();
      for (int i = 0; i < 3; i++) {
        await dao.incrementRetryCount(items.first.id);
      }

      final count = await dao.getCount();
      expect(count, 1); // Still counted even though failed
    });

    test('getByEntityType filters correctly', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'account',
        entityId: 'acc_1',
        operation: 'create',
        data: {'id': 'acc_1'},
      );
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_2',
        operation: 'update',
        data: {'id': 'txn_2'},
      );

      final txnItems = await dao.getByEntityType('transaction');
      expect(txnItems.length, 2);

      final accItems = await dao.getByEntityType('account');
      expect(accItems.length, 1);
    });

    test('delete by id removes single item', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'account',
        entityId: 'acc_1',
        operation: 'create',
        data: {'id': 'acc_1'},
      );

      final items = await dao.getAll();
      await dao.delete(items.first.id);

      final remaining = await dao.getAll();
      expect(remaining.length, 1);
    });

    test('deleteByEntity removes by type+id composite', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'account',
        entityId: 'acc_1',
        operation: 'create',
        data: {'id': 'acc_1'},
      );

      final deleted = await dao.deleteByEntity('transaction', 'txn_1');
      expect(deleted, 1);

      final remaining = await dao.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.entityType, 'account');
    });

    test('incrementRetryCount increments and sets error message', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );

      final items = await dao.getAll();
      await dao.incrementRetryCount(items.first.id, errorMessage: 'API error');

      final updated = await dao.getAll();
      expect(updated.first.retryCount, 1);
      expect(updated.first.errorMessage, 'API error');
    });

    test('after 3 increments item no longer in getPending', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );

      final items = await dao.getAll();
      for (int i = 0; i < 3; i++) {
        await dao.incrementRetryCount(items.first.id);
      }

      final pending = await dao.getPending();
      expect(pending, isEmpty);

      // But still in getAll
      final all = await dao.getAll();
      expect(all.length, 1);
      expect(all.first.retryCount, 3);
    });

    test('resetFailedItems resets retry_count for matching entity types',
        () async {
      await dao.enqueue(
        entityType: 'person',
        entityId: 'per_1',
        operation: 'create',
        data: {'id': 'per_1'},
      );
      await dao.enqueue(
        entityType: 'loan',
        entityId: 'loan_1',
        operation: 'create',
        data: {'id': 'loan_1'},
      );
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );

      // Fail all items
      final items = await dao.getAll();
      for (final item in items) {
        for (int i = 0; i < 3; i++) {
          await dao.incrementRetryCount(item.id, errorMessage: 'Failed');
        }
      }

      // Reset only person and loan
      final resetCount = await dao.resetFailedItems(['person', 'loan']);
      expect(resetCount, 2);

      // Person and loan should be pending again
      final pending = await dao.getPending();
      expect(pending.length, 2);
      final types = pending.map((p) => p.entityType).toSet();
      expect(types, contains('person'));
      expect(types, contains('loan'));
    });

    test('deleteCompleted removes items with retry_count >= 3', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_2',
        operation: 'create',
        data: {'id': 'txn_2'},
      );

      // Fail txn_1
      final items = await dao.getAll();
      for (int i = 0; i < 3; i++) {
        await dao.incrementRetryCount(items.first.id);
      }

      final deleted = await dao.deleteCompleted();
      expect(deleted, 1);

      final remaining = await dao.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.entityId, 'txn_2');
    });

    test('deleteAll clears everything', () async {
      await dao.enqueue(
        entityType: 'transaction',
        entityId: 'txn_1',
        operation: 'create',
        data: {'id': 'txn_1'},
      );
      await dao.enqueue(
        entityType: 'account',
        entityId: 'acc_1',
        operation: 'create',
        data: {'id': 'acc_1'},
      );

      await dao.deleteAll();

      final count = await dao.getCount();
      expect(count, 0);
    });
  });
}
