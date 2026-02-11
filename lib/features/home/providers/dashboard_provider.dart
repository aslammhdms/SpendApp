import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/budget.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/loan_repository.dart';
import '../../../data/local/local_loan_dao.dart';
import '../../../data/local/local_transaction_dao.dart';
import '../../../data/local/local_account_dao.dart';
import '../../../data/local/local_category_dao.dart';
import '../../../data/local/sync_queue_dao.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/remote/sync_engine.dart';
import '../../../core/utils/date_utils.dart';
import '../../onboarding/providers/sheet_setup_provider.dart';

class DashboardData {
  final double monthlyIncome;
  final double monthlyExpense;
  final double totalBalance;
  final List<Transaction> recentTransactions;
  final Map<DateTime, double> weeklySpending;
  final List<Budget> budgets;
  final double totalOwedToYou;
  final double totalYouOwe;
  final bool isLoading;
  final String? error;

  const DashboardData({
    this.monthlyIncome = 0,
    this.monthlyExpense = 0,
    this.totalBalance = 0,
    this.recentTransactions = const [],
    this.weeklySpending = const {},
    this.budgets = const [],
    this.totalOwedToYou = 0,
    this.totalYouOwe = 0,
    this.isLoading = true,
    this.error,
  });

  double get monthlyBalance => monthlyIncome - monthlyExpense;

  DashboardData copyWith({
    double? monthlyIncome,
    double? monthlyExpense,
    double? totalBalance,
    List<Transaction>? recentTransactions,
    Map<DateTime, double>? weeklySpending,
    List<Budget>? budgets,
    double? totalOwedToYou,
    double? totalYouOwe,
    bool? isLoading,
    String? error,
  }) {
    return DashboardData(
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      totalBalance: totalBalance ?? this.totalBalance,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      weeklySpending: weeklySpending ?? this.weeklySpending,
      budgets: budgets ?? this.budgets,
      totalOwedToYou: totalOwedToYou ?? this.totalOwedToYou,
      totalYouOwe: totalYouOwe ?? this.totalYouOwe,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardData> {
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;
  final BudgetRepository _budgetRepo;
  final LoanRepository _loanRepo;

  DashboardNotifier({
    required TransactionRepository transactionRepo,
    required AccountRepository accountRepo,
    required BudgetRepository budgetRepo,
    required LoanRepository loanRepo,
  })  : _transactionRepo = transactionRepo,
        _accountRepo = accountRepo,
        _budgetRepo = budgetRepo,
        _loanRepo = loanRepo,
        super(const DashboardData());

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final now = DateTime.now();

      // Get monthly totals
      final monthlyIncome = await _transactionRepo.getMonthlyIncome(now);
      final monthlyExpense = await _transactionRepo.getMonthlyExpense(now);

      // Get total balance
      final totalBalance = await _accountRepo.getTotalBalance();

      // Get recent transactions
      final recentTransactions = await _transactionRepo.getRecent(10);

      // Get weekly spending
      final weeklySpending = await _transactionRepo.getDailySpending(7);

      // Get budgets with progress
      final budgets = await _budgetRepo.getAll();

      // Get loan totals
      final totalOwedToYou = await _loanRepo.getTotalOwedToYou();
      final totalYouOwe = await _loanRepo.getTotalYouOwe();

      state = DashboardData(
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
        totalBalance: totalBalance,
        recentTransactions: recentTransactions,
        weeklySpending: weeklySpending,
        budgets: budgets,
        totalOwedToYou: totalOwedToYou,
        totalYouOwe: totalYouOwe,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard data: $e',
      );
    }
  }
}

// Provider dependencies
final localTransactionDaoProvider = Provider<LocalTransactionDao>((ref) {
  return LocalTransactionDao();
});

final localAccountDaoProvider = Provider<LocalAccountDao>((ref) {
  return LocalAccountDao();
});

final syncQueueDaoProvider = Provider<SyncQueueDao>((ref) {
  return SyncQueueDao();
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    sheetsService: ref.watch(sheetsServiceProvider),
    transactionDao: ref.watch(localTransactionDaoProvider),
    categoryDao: ref.watch(localCategoryDaoProvider),
    accountDao: ref.watch(localAccountDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
  );
});

final localCategoryDaoProvider = Provider((ref) {
  return LocalCategoryDao();
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    localDao: ref.watch(localTransactionDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    localDao: ref.watch(localAccountDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    transactionDao: ref.watch(localTransactionDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    localDao: ref.watch(localCategoryDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final localLoanDaoProvider = Provider((ref) {
  return LocalLoanDao();
});

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(
    localDao: ref.watch(localLoanDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardData>((ref) {
  return DashboardNotifier(
    transactionRepo: ref.watch(transactionRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    budgetRepo: ref.watch(budgetRepositoryProvider),
    loanRepo: ref.watch(loanRepositoryProvider),
  );
});
