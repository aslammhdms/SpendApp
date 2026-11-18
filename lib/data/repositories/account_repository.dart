import '../models/account.dart';
import '../local/local_account_dao.dart';
import '../local/sync_queue_dao.dart';
import '../remote/sync_engine.dart';
import '../../core/utils/id_generator.dart';

class AccountRepository {
  final LocalAccountDao _localDao;
  final SyncEngine _syncEngine;

  AccountRepository({
    required LocalAccountDao localDao,
    // Unused: changes are queued through the sync engine. Kept so callers
    // do not have to change.
    required SyncQueueDao syncQueueDao,
    required SyncEngine syncEngine,
  })  : _localDao = localDao,
        _syncEngine = syncEngine;

  Future<List<Account>> getAll({bool includeDeleted = false}) async {
    return await _localDao.getAll(includeDeleted: includeDeleted);
  }

  Future<List<Account>> getAllWithBalances() async {
    final accounts = await _localDao.getAll();
    final balances = await _localDao.calculateAllBalances();

    return accounts.map((account) {
      return account.copyWith(
        currentBalance: balances[account.id] ?? account.initialBalance,
      );
    }).toList();
  }

  Future<Account?> getById(String id) async {
    return await _localDao.getById(id);
  }

  Future<Account?> getByIdWithBalance(String id) async {
    final account = await _localDao.getById(id);
    if (account == null) return null;

    final balance = await _localDao.calculateBalance(id);
    return account.copyWith(currentBalance: balance);
  }

  Future<List<Account>> getByType(AccountType type) async {
    return await _localDao.getByType(type);
  }

  Future<double> getBalance(String accountId) async {
    return await _localDao.calculateBalance(accountId);
  }

  Future<double> getTotalBalance() async {
    final balances = await _localDao.calculateAllBalances();
    return balances.values.fold<double>(0.0, (double sum, double balance) => sum + balance);
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    required double initialBalance,
    required String currency,
    required String icon,
    required int color,
  }) async {
    final now = DateTime.now();
    final sortOrder = await _localDao.getNextSortOrder();

    final account = Account(
      id: IdGenerator.generate(),
      name: name,
      type: type,
      initialBalance: initialBalance,
      currency: currency,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      currentBalance: initialBalance,
    );

    // Save locally first
    await _localDao.insert(account);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'account',
      entityId: account.id,
      operation: 'create',
      data: account.toJson(),
    );

    return account;
  }

  Future<Account> update(Account account) async {
    final updated = account.copyWith(updatedAt: DateTime.now());

    // Update locally first
    await _localDao.update(updated);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'account',
      entityId: updated.id,
      operation: 'update',
      data: updated.toJson(),
    );

    return updated;
  }

  Future<void> delete(String id) async {
    final account = await _localDao.getById(id);
    if (account == null) return;

    final deleted = account.copyWithDelete();

    // Soft delete locally
    await _localDao.update(deleted);

    // Queue for sync
    await _syncEngine.queueOperation(
      entityType: 'account',
      entityId: id,
      operation: 'delete',
      data: deleted.toJson(),
    );
  }

  Future<void> reorder(List<Account> accounts) async {
    await _localDao.updateSortOrders(accounts);

    // Queue each update for sync
    for (final account in accounts) {
      await _syncEngine.queueOperation(
        entityType: 'account',
        entityId: account.id,
        operation: 'update',
        data: account.toJson(),
      );
    }
  }
}
