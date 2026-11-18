import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/signal_stat.dart';
import '../providers/analytics_provider.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/spending_line_chart.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/glass_app_bar.dart';

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

    // The period control sits in the app bar, with a little air under it.
    const periodBarHeight = SegmentedControl.height + Space.sm;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(periodBarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              0,
              Space.lg,
              Space.sm,
            ),
            child: SegmentedControl<AnalyticsPeriod>(
              segments: const {
                AnalyticsPeriod.week: 'Week',
                AnalyticsPeriod.month: 'Month',
                AnalyticsPeriod.year: 'Year',
              },
              selected: notifier.period,
              onChanged: notifier.setPeriod,
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
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: Space.lg),
                      Text(analytics.error!),
                      const SizedBox(height: Space.lg),
                      FilledButton(
                        onPressed: () => notifier.loadData(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.loadData(),
                  edgeOffset: ScreenInsets.topOf(
                    context,
                    appBarBottom: periodBarHeight,
                  ),
                  child: ListView(
                    padding: ScreenInsets.of(
                      context,
                      appBarBottom: periodBarHeight,
                      bottom: Space.xxl,
                    ),
                    children: [
                      // Summary Card
                      _SummaryCard(
                        totalIncome: analytics.totalIncome,
                        totalExpense: analytics.totalExpense,
                        currency: currency,
                      ),
                      const SizedBox(height: Space.lg),

                      // Category Breakdown
                      CategoryPieChart(
                        categoryTotals: analytics.categoryTotals,
                        totalAmount: analytics.totalExpense,
                        currency: currency,
                      ),
                      const SizedBox(height: Space.lg),

                      // Daily Spending Trend
                      SpendingLineChart(
                        dailySpending: analytics.dailyExpenses,
                        currency: currency,
                      ),
                      const SizedBox(height: Space.lg),

                      // Monthly Income vs Expense (for year view)
                      if (notifier.period == AnalyticsPeriod.year) ...[
                        IncomeExpenseBarChart(
                          monthlyExpenses: analytics.monthlyExpenses,
                          monthlyIncome: analytics.monthlyIncome,
                          currency: currency,
                        ),
                        const SizedBox(height: Space.lg),
                      ],
                    ],
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final balance = totalIncome - totalExpense;
    final net = CurrencyUtils.formatWithSign(balance, currencyCode: currency);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net',
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Semantics(
              label: 'Net, $net',
              excludeSemantics: true,
              child: Text(
                net,
                style: text.headlineMedium?.tabular,
              ),
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: SignalStat(
                    label: 'Income',
                    amount: totalIncome,
                    kind: MoneyKind.income,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: SignalStat(
                    label: 'Expense',
                    amount: totalExpense,
                    kind: MoneyKind.expense,
                    currency: currency,
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
