import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_recurring_dao.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/repositories/recurring_repository.dart';
import '../../home/providers/dashboard_provider.dart';

final localRecurringDaoProvider = Provider<LocalRecurringDao>((ref) {
  return LocalRecurringDao();
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(
    dao: ref.watch(localRecurringDaoProvider),
    transactionDao: ref.watch(localTransactionDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

/// Live repeating payments, soonest due first. Invalidate after a change.
final recurringRulesProvider = FutureProvider<List<RecurringRule>>((ref) {
  return ref.watch(recurringRepositoryProvider).getAll();
});
