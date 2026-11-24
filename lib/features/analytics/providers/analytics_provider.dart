import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../core/utils/date_utils.dart';
import '../../home/providers/dashboard_provider.dart';

class AnalyticsData {
  final Map<String, double> categoryTotals;
  final Map<DateTime, double> dailyExpenses;
  final Map<DateTime, double> monthlyExpenses;
  final Map<DateTime, double> monthlyIncome;
  final double totalExpense;
  final double totalIncome;

  /// Expense totals by label in the period.
  final Map<String, double> labelTotals;

  /// The period the figures cover.
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool isLoading;
  final String? error;

  const AnalyticsData({
    this.categoryTotals = const {},
    this.dailyExpenses = const {},
    this.monthlyExpenses = const {},
    this.monthlyIncome = const {},
    this.totalExpense = 0,
    this.totalIncome = 0,
    this.labelTotals = const {},
    this.periodStart,
    this.periodEnd,
    this.isLoading = true,
    this.error,
  });

  AnalyticsData copyWith({
    Map<String, double>? categoryTotals,
    Map<DateTime, double>? dailyExpenses,
    Map<DateTime, double>? monthlyExpenses,
    Map<DateTime, double>? monthlyIncome,
    double? totalExpense,
    double? totalIncome,
    bool? isLoading,
    String? error,
  }) {
    return AnalyticsData(
      categoryTotals: categoryTotals ?? this.categoryTotals,
      dailyExpenses: dailyExpenses ?? this.dailyExpenses,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      labelTotals: labelTotals,
      periodStart: periodStart,
      periodEnd: periodEnd,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

enum AnalyticsPeriod {
  week,
  month,
  year,
}

class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  final TransactionRepository _repository;
  AnalyticsPeriod _period = AnalyticsPeriod.month;

  AnalyticsNotifier(this._repository) : super(const AnalyticsData());

  AnalyticsPeriod get period => _period;

  void setPeriod(AnalyticsPeriod period) {
    _period = period;
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final now = DateTime.now();
      late DateTime startDate;
      late DateTime endDate;

      switch (_period) {
        case AnalyticsPeriod.week:
          startDate = AppDateUtils.startOfWeek(now);
          endDate = AppDateUtils.endOfWeek(now);
          break;
        case AnalyticsPeriod.month:
          startDate = AppDateUtils.startOfMonth(now);
          endDate = AppDateUtils.endOfMonth(now);
          break;
        case AnalyticsPeriod.year:
          startDate = AppDateUtils.startOfYear(now);
          endDate = AppDateUtils.endOfYear(now);
          break;
      }

      // Category totals
      final categoryTotals = await _repository.getTotalsByCategory(
        startDate,
        endDate,
      );

      // Total expense
      final totalExpense = await _repository.getTotalByTypeAndDateRange(
        TransactionType.expense,
        startDate,
        endDate,
      );

      // Total income
      final totalIncome = await _repository.getTotalByTypeAndDateRange(
        TransactionType.income,
        startDate,
        endDate,
      );

      final labelTotals =
          await _repository.getExpenseTotalsByLabel(startDate, endDate);

      // Daily expenses for the period
      final dailyExpenses = await _repository.getDailySpending(
        _period == AnalyticsPeriod.week ? 7 : 30,
      );

      // Monthly data for year view
      Map<DateTime, double> monthlyExpenses = {};
      Map<DateTime, double> monthlyIncome = {};

      if (_period == AnalyticsPeriod.year) {
        for (int month = 1; month <= 12; month++) {
          final monthStart = DateTime(now.year, month, 1);
          final monthEnd = DateTime(now.year, month + 1, 0, 23, 59, 59);

          final expense = await _repository.getTotalByTypeAndDateRange(
            TransactionType.expense,
            monthStart,
            monthEnd,
          );
          final income = await _repository.getTotalByTypeAndDateRange(
            TransactionType.income,
            monthStart,
            monthEnd,
          );

          monthlyExpenses[monthStart] = expense;
          monthlyIncome[monthStart] = income;
        }
      }

      state = AnalyticsData(
        categoryTotals: categoryTotals,
        dailyExpenses: dailyExpenses,
        monthlyExpenses: monthlyExpenses,
        monthlyIncome: monthlyIncome,
        totalExpense: totalExpense,
        totalIncome: totalIncome,
        labelTotals: labelTotals,
        periodStart: startDate,
        periodEnd: endDate,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load analytics: $e',
      );
    }
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsData>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return AnalyticsNotifier(repository);
});
