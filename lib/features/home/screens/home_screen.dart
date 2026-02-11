import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/remote/sync_engine.dart';
import '../../../shared/widgets/sync_indicator.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/spending_trend_chart.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/budget_progress_bars.dart';
import '../widgets/loans_summary_card.dart';
import '../../settings/providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    // Load dashboard data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).refresh();
      _listenToSync();
    });
  }

  void _listenToSync() {
    _syncSubscription = ref.read(syncEngineProvider).statusStream.listen((status) {
      if (status == SyncStatus.synced && mounted) {
        ref.read(dashboardProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await ref.read(dashboardProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardData = ref.watch(dashboardProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpendSheet'),
        actions: const [
          SyncIndicator(),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: dashboardData.isLoading
            ? const Center(child: CircularProgressIndicator())
            : dashboardData.error != null
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
                        Text(
                          dashboardData.error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _handleRefresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      MonthlySummaryCard(
                        income: dashboardData.monthlyIncome,
                        expense: dashboardData.monthlyExpense,
                        balance: dashboardData.monthlyBalance,
                        currency: currency,
                      ),
                      const SizedBox(height: 16),
                      SpendingTrendChart(
                        dailySpending: dashboardData.weeklySpending,
                        currency: currency,
                      ),
                      const SizedBox(height: 16),
                      BudgetProgressBars(
                        budgets: dashboardData.budgets,
                        onViewAll: () => context.go('/budgets'),
                        currency: currency,
                      ),
                      const SizedBox(height: 16),
                      LoansSummaryCard(
                        totalOwedToYou: dashboardData.totalOwedToYou,
                        totalYouOwe: dashboardData.totalYouOwe,
                        onTap: () => context.push('/loans'),
                        currency: currency,
                      ),
                      const SizedBox(height: 16),
                      RecentTransactionsList(
                        transactions: dashboardData.recentTransactions,
                        onViewAll: () => context.go('/transactions'),
                        onTap: (transaction) {
                          context.push('/transactions/edit/${transaction.id}');
                        },
                        currency: currency,
                      ),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
