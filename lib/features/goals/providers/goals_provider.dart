import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_goal_dao.dart';
import '../../../data/models/goal.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../home/providers/dashboard_provider.dart';

final localGoalDaoProvider = Provider<LocalGoalDao>((ref) {
  return LocalGoalDao();
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(
    dao: ref.watch(localGoalDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

/// Live savings goals, oldest first. Invalidate after a change.
final goalsProvider = FutureProvider<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).getAll();
});
