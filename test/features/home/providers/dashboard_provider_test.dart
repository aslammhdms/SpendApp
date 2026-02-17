import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';
import 'package:spendsheet/data/repositories/account_repository.dart';
import 'package:spendsheet/data/repositories/budget_repository.dart';
import 'package:spendsheet/data/repositories/loan_repository.dart';
import 'package:spendsheet/features/home/providers/dashboard_provider.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAccountRepository extends Mock implements AccountRepository {}
class MockBudgetRepository extends Mock implements BudgetRepository {}
class MockLoanRepository extends Mock implements LoanRepository {}

void main() {
  late MockTransactionRepository mockTxnRepo;
  late MockAccountRepository mockAccRepo;
  late MockBudgetRepository mockBudgetRepo;
  late MockLoanRepository mockLoanRepo;
  late DashboardNotifier notifier;

  setUp(() {
    mockTxnRepo = MockTransactionRepository();
    mockAccRepo = MockAccountRepository();
    mockBudgetRepo = MockBudgetRepository();
    mockLoanRepo = MockLoanRepository();

    notifier = DashboardNotifier(
      transactionRepo: mockTxnRepo,
      accountRepo: mockAccRepo,
      budgetRepo: mockBudgetRepo,
      loanRepo: mockLoanRepo,
    );
  });

  void _stubAllRepos({
    double income = 0,
    double expense = 0,
    double totalBalance = 0,
    List<Transaction> recent = const [],
    Map<DateTime, double> weekly = const {},
    List<Budget> budgets = const [],
    double owedToYou = 0,
    double youOwe = 0,
  }) {
    when(() => mockTxnRepo.getMonthlyIncome(any()))
        .thenAnswer((_) async => income);
    when(() => mockTxnRepo.getMonthlyExpense(any()))
        .thenAnswer((_) async => expense);
    when(() => mockAccRepo.getTotalBalance())
        .thenAnswer((_) async => totalBalance);
    when(() => mockTxnRepo.getRecent(any()))
        .thenAnswer((_) async => recent);
    when(() => mockTxnRepo.getDailySpending(any()))
        .thenAnswer((_) async => weekly);
    when(() => mockBudgetRepo.getAll())
        .thenAnswer((_) async => budgets);
    when(() => mockLoanRepo.getTotalOwedToYou())
        .thenAnswer((_) async => owedToYou);
    when(() => mockLoanRepo.getTotalYouOwe())
        .thenAnswer((_) async => youOwe);
  }

  group('DashboardNotifier', () {
    test('initial state is loading with zero values', () {
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.monthlyIncome, 0);
      expect(notifier.state.monthlyExpense, 0);
      expect(notifier.state.totalBalance, 0);
      expect(notifier.state.recentTransactions, isEmpty);
    });

    test('refresh loads all data', () async {
      _stubAllRepos(
        income: 5000,
        expense: 3000,
        totalBalance: 10000,
        owedToYou: 500,
        youOwe: 200,
      );

      await notifier.refresh();

      expect(notifier.state.monthlyIncome, 5000);
      expect(notifier.state.monthlyExpense, 3000);
      expect(notifier.state.totalBalance, 10000);
      expect(notifier.state.totalOwedToYou, 500);
      expect(notifier.state.totalYouOwe, 200);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('monthlyBalance computed correctly', () async {
      _stubAllRepos(income: 5000, expense: 3000);

      await notifier.refresh();

      expect(notifier.state.monthlyBalance, 2000);
    });

    test('error from repo sets error message', () async {
      when(() => mockTxnRepo.getMonthlyIncome(any()))
          .thenThrow(Exception('Network error'));
      when(() => mockTxnRepo.getMonthlyExpense(any()))
          .thenAnswer((_) async => 0);
      when(() => mockAccRepo.getTotalBalance())
          .thenAnswer((_) async => 0);
      when(() => mockTxnRepo.getRecent(any()))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getDailySpending(any()))
          .thenAnswer((_) async => {});
      when(() => mockBudgetRepo.getAll())
          .thenAnswer((_) async => []);
      when(() => mockLoanRepo.getTotalOwedToYou())
          .thenAnswer((_) async => 0);
      when(() => mockLoanRepo.getTotalYouOwe())
          .thenAnswer((_) async => 0);

      await notifier.refresh();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Failed to load'));
    });

    test('empty data returns zero values', () async {
      _stubAllRepos();

      await notifier.refresh();

      expect(notifier.state.monthlyIncome, 0);
      expect(notifier.state.monthlyExpense, 0);
      expect(notifier.state.totalBalance, 0);
      expect(notifier.state.recentTransactions, isEmpty);
      expect(notifier.state.weeklySpending, isEmpty);
      expect(notifier.state.budgets, isEmpty);
    });

    test('refresh sets isLoading true then false', () async {
      _stubAllRepos();

      final loadingStates = <bool>[];
      notifier.addListener((state) {
        loadingStates.add(state.isLoading);
      });

      await notifier.refresh();

      expect(loadingStates, contains(true));
      expect(loadingStates.last, isFalse);
    });

    test('DashboardData copyWith works correctly', () {
      const data = DashboardData(monthlyIncome: 1000);
      final updated = data.copyWith(monthlyExpense: 500);

      expect(updated.monthlyIncome, 1000);
      expect(updated.monthlyExpense, 500);
    });

    test('DashboardData error field clears on null', () {
      const data = DashboardData(error: 'Some error');
      final updated = data.copyWith(error: null);

      // copyWith uses error directly, so null is valid
      expect(updated.error, isNull);
    });
  });
}
