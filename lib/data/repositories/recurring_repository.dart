import 'package:flutter/foundation.dart' hide Category;
import '../../core/utils/id_generator.dart';
import '../local/local_recurring_dao.dart';
import '../local/local_transaction_dao.dart';
import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import '../remote/sync_engine.dart';

/// Repeating payments, and adding their transactions when they fall due.
class RecurringRepository {
  final LocalRecurringDao _dao;
  final LocalTransactionDao _transactionDao;
  final SyncEngine _syncEngine;

  RecurringRepository({
    required LocalRecurringDao dao,
    required LocalTransactionDao transactionDao,
    required SyncEngine syncEngine,
  })  : _dao = dao,
        _transactionDao = transactionDao,
        _syncEngine = syncEngine;

  /// Most transactions one rule adds in one go, for a phone that was off
  /// for a long time or a rule whose date was set far in the past.
  static const int maxCatchUp = 60;

  Future<List<RecurringRule>> getAll() => _dao.getAll();

  Future<RecurringRule?> getById(String id) => _dao.getById(id);

  /// Makes [first] repeat every [interval] [frequency]. [first] is already
  /// saved; the rule's next date is the one after it.
  Future<RecurringRule> createFrom(
    Transaction first, {
    required RecurringFrequency frequency,
    required String name,
    int interval = 1,
  }) async {
    final now = DateTime.now();
    final draft = RecurringRule(
      id: IdGenerator.generate(),
      name: name,
      amount: first.amount,
      type: first.type,
      categoryId: first.categoryId,
      accountId: first.accountId,
      frequency: frequency,
      interval: interval,
      nextDueDate: first.date,
      note: first.note,
      createdAt: now,
      updatedAt: now,
    );
    final rule = draft.copyWith(nextDueDate: draft.calculateNextDueDate());
    await _dao.insert(rule);
    await _queue(rule, 'create');
    return rule;
  }

  Future<RecurringRule> update(RecurringRule rule) async {
    final updated = rule.copyWith(updatedAt: DateTime.now());
    await _dao.update(updated);
    await _queue(updated, 'update');
    return updated;
  }

  Future<RecurringRule> setActive(RecurringRule rule, bool active) =>
      update(rule.copyWith(isActive: active));

  /// Stops the rule. Transactions it already added stay.
  Future<void> delete(String id) async {
    final rule = await _dao.getById(id);
    if (rule == null) return;
    final deleted = rule.copyWith(
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _dao.update(deleted);
    await _queue(deleted, 'delete');
  }

  /// Adds a transaction for every occurrence that has come due by [now],
  /// moves each rule on to its next date, and returns how many were added.
  ///
  /// Each occurrence gets an ID made from the rule and its date, so a second
  /// phone that adds the same occurrence writes the same sheet row rather
  /// than a second one, and an occurrence the user deleted is not added
  /// again on this phone.
  Future<int> processDue(DateTime now) async {
    var added = 0;
    for (final rule in await _dao.getAll()) {
      if (!rule.isActive || rule.isDeleted) continue;
      try {
        added += await _processRule(rule, now);
      } catch (e) {
        debugPrint('Repeating payment ${rule.id} failed: $e');
      }
    }
    return added;
  }

  Future<int> _processRule(RecurringRule rule, DateTime now) async {
    var current = rule;
    var added = 0;
    var steps = 0;
    while (!current.nextDueDate.isAfter(now) && steps < maxCatchUp) {
      if (_isPastEnd(current, current.nextDueDate)) break;
      final id = occurrenceId(rule.id, current.nextDueDate);
      if (await _transactionDao.getById(id) == null) {
        final stamp = DateTime.now();
        final transaction = Transaction(
          id: id,
          date: current.nextDueDate,
          amount: rule.amount,
          type: rule.type,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          note: rule.note?.isNotEmpty == true ? rule.note : rule.name,
          recurringId: rule.id,
          createdAt: stamp,
          updatedAt: stamp,
        );
        await _transactionDao.insert(transaction);
        await _syncEngine.queueOperation(
          entityType: 'transaction',
          entityId: id,
          operation: 'create',
          data: transaction.toJson(),
        );
        added++;
      }
      current = current.copyWith(nextDueDate: current.calculateNextDueDate());
      steps++;
    }

    final ended = _isPastEnd(current, current.nextDueDate);
    if (steps > 0 || ended) {
      await update(current.copyWith(isActive: !ended));
    }
    return added;
  }

  static bool _isPastEnd(RecurringRule rule, DateTime date) {
    final end = rule.endDate;
    if (end == null) return false;
    return date.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
  }

  /// The ID of the transaction [ruleId] adds on [date].
  static String occurrenceId(String ruleId, DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'rec-$ruleId-${date.year}${two(date.month)}${two(date.day)}';
  }

  Future<void> _queue(RecurringRule rule, String operation) {
    return _syncEngine.queueOperation(
      entityType: 'recurring',
      entityId: rule.id,
      operation: operation,
      data: rule.toJson(),
    );
  }
}
