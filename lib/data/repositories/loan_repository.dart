import '../models/loan.dart';
import '../local/local_loan_dao.dart';
import '../local/sync_queue_dao.dart';
import '../remote/sync_engine.dart';
import '../../core/utils/id_generator.dart';

class LoanRepository {
  final LocalLoanDao _localDao;
  final SyncEngine _syncEngine;

  LoanRepository({
    required LocalLoanDao localDao,
    // Unused: changes are queued through the sync engine. Kept so callers
    // do not have to change.
    required SyncQueueDao syncQueueDao,
    required SyncEngine syncEngine,
  })  : _localDao = localDao,
        _syncEngine = syncEngine;

  Future<List<Loan>> getAll({bool includeDeleted = false}) async {
    return await _localDao.getAll(includeDeleted: includeDeleted);
  }

  Future<Loan?> getById(String id) async {
    return await _localDao.getById(id);
  }

  Future<List<Loan>> getByPersonId(String personId) async {
    return await _localDao.getByPersonId(personId);
  }

  Future<double> getPersonBalance(String personId) async {
    return await _localDao.calculatePersonBalance(personId);
  }

  Future<Map<String, double>> getAllBalances() async {
    return await _localDao.calculateAllBalances();
  }

  Future<double> getTotalOwedToYou() async {
    return await _localDao.getTotalOwedToYou();
  }

  Future<double> getTotalYouOwe() async {
    return await _localDao.getTotalYouOwe();
  }

  Future<Loan> create({
    required String personId,
    required LoanType type,
    required double amount,
    required DateTime date,
    String? note,
    bool isSettlement = false,
  }) async {
    final now = DateTime.now();

    final loan = Loan(
      id: IdGenerator.generate(),
      personId: personId,
      type: type,
      amount: amount,
      note: note,
      date: date,
      isSettlement: isSettlement,
      createdAt: now,
      updatedAt: now,
    );

    await _localDao.insert(loan);

    await _syncEngine.queueOperation(
      entityType: 'loan',
      entityId: loan.id,
      operation: 'create',
      data: loan.toJson(),
    );

    return loan;
  }

  Future<Loan> update(Loan loan) async {
    final updated = loan.copyWith(updatedAt: DateTime.now());

    await _localDao.update(updated);

    await _syncEngine.queueOperation(
      entityType: 'loan',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );

    return updated;
  }

  Future<void> delete(String id) async {
    final loan = await _localDao.getById(id);
    if (loan == null) return;

    final deleted = loan.copyWithDelete();

    await _localDao.update(deleted);

    await _syncEngine.queueOperation(
      entityType: 'loan',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<Loan> settle({
    required String personId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final balance = await _localDao.calculatePersonBalance(personId);

    // If balance > 0, they owe you → settlement is "borrowed" (they pay back)
    // If balance < 0, you owe them → settlement is "lent" (you pay back)
    final type = balance > 0 ? LoanType.borrowed : LoanType.lent;

    return create(
      personId: personId,
      type: type,
      amount: amount,
      date: date,
      note: note,
      isSettlement: true,
    );
  }
}
