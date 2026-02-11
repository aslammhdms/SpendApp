import 'package:sqflite/sqflite.dart';
import '../models/person.dart';
import 'database_helper.dart';

class LocalPersonDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> insert(Person person) async {
    final db = await _db;
    return await db.insert(
      'people',
      _toMap(person),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Person person) async {
    final db = await _db;
    return await db.update(
      'people',
      _toMap(person),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'people',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Person?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<List<Person>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('people', orderBy: 'name ASC');
    } else {
      maps = await db.query(
        'people',
        where: 'deleted_at IS NULL',
        orderBy: 'name ASC',
      );
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<List<Person>> search(String query) async {
    final db = await _db;
    final maps = await db.query(
      'people',
      where: 'name LIKE ? AND deleted_at IS NULL',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => _fromMap(map)).toList();
  }

  Future<int> insertBatch(List<Person> people) async {
    final db = await _db;
    final batch = db.batch();
    for (final person in people) {
      batch.insert(
        'people',
        _toMap(person),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    return results.length;
  }

  Future<int> deleteAll() async {
    final db = await _db;
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
