import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../providers/analytics_provider.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/spending_line_chart.dart';
import '../../settings/providers/settings_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsProvider);
    final notifier = ref.read(analyticsProvider.notifier);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _PeriodChip(
                  label: 'Week',
                  isSelected: notifier.period == AnalyticsPeriod.week,
                  onTap: () => notifier.setPeriod(AnalyticsPeriod.week),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: 'Month',
                  isSelected: notifier.period == AnalyticsPeriod.month,
                  onTap: () => notifier.setPeriod(AnalyticsPeriod.month),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: 'Year',
                  isSelected: notifier.period == AnalyticsPeriod.year,
                  onTap: () => notifier.setPeriod(AnalyticsPeriod.year),
                ),
              ],
            ),
          ),
        ),
      ),
      body: analytics.isLoading
          ? const Center(child: CircularProgressIndicator())
          : analytics.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(analytics.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => notifier.loadData(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.loadData(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Card
                      _SummaryCard(
                        totalIncome: analytics.totalIncome,
                        totalExpense: analytics.totalExpense,
                        currency: currency,
                      ),
                      const SizedBox(height: 16),

                      // Category Breakdown
                      CategoryPieChart(
                        categoryTotals: analytics.categoryTotals,
                        totalAmount: analytics.totalExpense,
                        currency: currency,
                      ),
                      const SizedBox(height: 16),

                      // Daily Spending Trend
                      SpendingLineChart(
                        dailySpending: analytics.dailyExpenses,
                        currency: currency,
                      ),
                      const SizedBox(height: 16),

                      // Monthly Income vs Expense (for year view)
                      if (notifier.period == AnalyticsPeriod.year) ...[
                        IncomeExpenseBarChart(
                          monthlyExpenses: analytics.monthlyExpenses,
                          monthlyIncome: analytics.monthlyIncome,
                          currency: currency,
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final String currency;

  const _SummaryCard({
    required this.totalIncome,
    required this.totalExpense,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final balance = totalIncome - totalExpense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: 'Income',
                    amount: totalIncome,
                    color: AppColors.income,
                    icon: Icons.arrow_downward,
                    currency: currency,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _SummaryItem(
                    label: 'Expense',
                    amount: totalExpense,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward,
                    currency: currency,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Net: ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  CurrencyUtils.formatWithSign(balance, currencyCode: currency),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: balance >= 0 ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final String currency;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtils.format(amount, currencyCode: currency),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
