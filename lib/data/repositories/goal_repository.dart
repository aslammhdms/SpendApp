import '../../core/utils/id_generator.dart';
import '../local/local_goal_dao.dart';
import '../models/goal.dart';
import '../remote/sync_engine.dart';

class GoalRepository {
  final LocalGoalDao _dao;
  final SyncEngine _syncEngine;

  GoalRepository({required LocalGoalDao dao, required SyncEngine syncEngine})
      : _dao = dao,
        _syncEngine = syncEngine;

  Future<List<Goal>> getAll() => _dao.getAll();

  Future<Goal?> getById(String id) => _dao.getById(id);

  Future<Goal> create({
    required String name,
    required double targetAmount,
    double savedAmount = 0,
    DateTime? targetDate,
    required String icon,
    required int color,
  }) async {
    final now = DateTime.now();
    final goal = Goal(
      id: IdGenerator.generate(),
      name: name.trim(),
      targetAmount: targetAmount,
      savedAmount: savedAmount < 0 ? 0 : savedAmount,
      targetDate: targetDate,
      icon: icon,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    await _dao.insert(goal);
    await _queue(goal, 'create');
    return goal;
  }

  Future<Goal> update(Goal goal) async {
    final updated = goal.copyWith(
      name: goal.name.trim(),
      updatedAt: DateTime.now(),
    );
    await _dao.update(updated);
    await _queue(updated, 'update');
    return updated;
  }

  /// Adds [amount] to what is saved; a negative amount takes money out.
  /// The saved amount never goes below zero.
  Future<Goal> addToSaved(Goal goal, double amount) {
    final saved = goal.savedAmount + amount;
    return update(goal.copyWith(savedAmount: saved < 0 ? 0 : saved));
  }

  Future<void> delete(String id) async {
    final goal = await _dao.getById(id);
    if (goal == null) return;
    final now = DateTime.now();
    final deleted = goal.copyWith(deletedAt: now, updatedAt: now);
    await _dao.update(deleted);
    await _queue(deleted, 'delete');
  }

  Future<void> _queue(Goal goal, String operation) {
    return _syncEngine.queueOperation(
      entityType: 'goal',
      entityId: goal.id,
      operation: operation,
      data: goal.toJson(),
    );
  }
}
