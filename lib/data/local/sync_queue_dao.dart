import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/app_settings.dart';
import 'database_helper.dart';

class SyncQueueDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(SyncQueueItem item) async {
    final db = await _db;
    return await db.insert(
      'sync_queue',
      _toMap(item),
    );
  }

  Future<int> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db;

    // Check for existing pending operation on same entity
    final existing = await db.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );

    if (existing.isNotEmpty) {
      // Update existing entry
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

    return await db.insert(
      'sync_queue',
      {
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      },
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByEntity(String entityType, String entityId) async {
    final db = await _db;
    return await db.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );
  }

  Future<List<SyncQueueItem>> getAll() async {
    final db = await _db;
    final maps = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<SyncQueueItem>> getPending({int limit = 50}) async {
    final db = await _db;
    final maps = await db.query(
      'sync_queue',
      where: 'retry_count < 3',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<SyncQueueItem>> getByEntityType(String entityType) async {
    final db = await _db;
    final maps = await db.query(
      'sync_queue',
      where: 'entity_type = ?',
      whereArgs: [entityType],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<int> incrementRetryCount(int id, {String? errorMessage}) async {
    final db = await _db;
    return await db.rawUpdate('''
      UPDATE sync_queue
      SET retry_count = retry_count + 1,
          error_message = ?
      WHERE id = ?
    ''', [errorMessage, id]);
  }

  Future<int> getCount() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sync_queue
    ''');
    return (result.first['count'] as num).toInt();
  }

  Future<int> getPendingCount() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sync_queue WHERE retry_count < 3
    ''');
    return (result.first['count'] as num).toInt();
  }

  Future<int> deleteAll() async {
    final db = await _db;
    return await db.delete('sync_queue');
  }

  Future<int> resetFailedItems(List<String> entityTypes) async {
    if (entityTypes.isEmpty) return 0;
    final db = await _db;
    final placeholders = entityTypes.map((_) => '?').join(', ');
    return await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = 0, error_message = NULL '
      'WHERE entity_type IN ($placeholders) AND retry_count >= 3',
      entityTypes,
    );
  }

  Future<int> deleteCompleted() async {
    final db = await _db;
    return await db.delete(
      'sync_queue',
      where: 'retry_count >= 3',
    );
  }

  Map<String, dynamic> _toMap(SyncQueueItem item) {
    return {
      'entity_type': item.entityType,
      'entity_id': item.entityId,
      'operation': item.operation,
      'data': item.data,
      'created_at': item.createdAt.toIso8601String(),
      'retry_count': item.retryCount,
      'error_message': item.errorMessage,
    };
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
