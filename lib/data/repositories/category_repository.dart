import '../models/category.dart';
import '../local/local_category_dao.dart';
import '../local/sync_queue_dao.dart';
import '../remote/sync_engine.dart';
import '../../core/utils/id_generator.dart';

class CategoryRepository {
  final LocalCategoryDao _localDao;
  final SyncQueueDao _syncQueueDao;
  final SyncEngine _syncEngine;

  CategoryRepository({
    required LocalCategoryDao localDao,
    required SyncQueueDao syncQueueDao,
    required SyncEngine syncEngine,
  })  : _localDao = localDao,
        _syncQueueDao = syncQueueDao,
        _syncEngine = syncEngine;

  Future<List<Category>> getAll({bool includeDeleted = false}) async {
    return await _localDao.getAll(includeDeleted: includeDeleted);
  }

  Future<Category?> getById(String id) async {
    return await _localDao.getById(id);
  }

  Future<List<Category>> getByType(CategoryType type) async {
    return await _localDao.getByType(type);
  }

  Future<List<Category>> getExpenseCategories() async {
    return await _localDao.getExpenseCategories();
  }

  Future<List<Category>> getIncomeCategories() async {
    return await _localDao.getIncomeCategories();
  }

  Future<Category> create({
    required String name,
    required CategoryType type,
    required String icon,
    required int color,
  }) async {
    final now = DateTime.now();
    final sortOrder = await _localDao.getNextSortOrder(type);

    final category = Category(
      id: IdGenerator.generate(),
      name: name,
      type: type,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    // Save locally first
    await _localDao.insert(category);

    // Queue for sync
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

    // Update locally first
    await _localDao.update(updated);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'category',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );

    return updated;
  }

  Future<void> delete(String id) async {
    final category = await _localDao.getById(id);
    if (category == null) return;

    final deleted = category.copyWithDelete();

    // Soft delete locally
    await _localDao.update(deleted);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'category',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<void> reorder(List<Category> categories) async {
    await _localDao.updateSortOrders(categories);

    // Queue each update for sync
    for (final category in categories) {
      await _syncEngine.queueOperation(
        entityType: 'category',
        entityId: category.id,
        operation: 'update',
        data: category.toJson(),
      );
    }
  }
}
