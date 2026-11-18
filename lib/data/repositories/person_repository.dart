import '../models/person.dart';
import '../local/local_person_dao.dart';
import '../local/sync_queue_dao.dart';
import '../remote/sync_engine.dart';
import '../../core/utils/id_generator.dart';

class PersonRepository {
  final LocalPersonDao _localDao;
  final SyncEngine _syncEngine;

  PersonRepository({
    required LocalPersonDao localDao,
    // Unused: changes are queued through the sync engine. Kept so callers
    // do not have to change.
    required SyncQueueDao syncQueueDao,
    required SyncEngine syncEngine,
  })  : _localDao = localDao,
        _syncEngine = syncEngine;

  Future<List<Person>> getAll({bool includeDeleted = false}) async {
    return await _localDao.getAll(includeDeleted: includeDeleted);
  }

  Future<Person?> getById(String id) async {
    return await _localDao.getById(id);
  }

  Future<List<Person>> search(String query) async {
    return await _localDao.search(query);
  }

  Future<Person> create({
    required String name,
    String? phone,
    String? note,
  }) async {
    final now = DateTime.now();

    final person = Person(
      id: IdGenerator.generate(),
      name: name,
      phone: phone,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    await _localDao.insert(person);

    await _syncEngine.queueOperation(
      entityType: 'person',
      entityId: person.id,
      operation: 'create',
      data: person.toJson(),
    );

    return person;
  }

  Future<Person> update(Person person) async {
    final updated = person.copyWith(updatedAt: DateTime.now());

    await _localDao.update(updated);

    await _syncEngine.queueOperation(
      entityType: 'person',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );

    return updated;
  }

  Future<void> delete(String id) async {
    final person = await _localDao.getById(id);
    if (person == null) return;

    final deleted = person.copyWithDelete();

    await _localDao.update(deleted);

    await _syncEngine.queueOperation(
      entityType: 'person',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }
}
