import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/remote/sync_engine.dart';
import '../../../shared/widgets/auto_hide_fab.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../shared/widgets/sync_indicator.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/spending_trend_chart.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/budget_progress_bars.dart';
import '../widgets/loans_summary_card.dart';
import '../widgets/plans_cards.dart';
import '../../goals/providers/goals_provider.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../wallet_capture/providers/wallet_capture_provider.dart';
import '../../wallet_capture/widgets/pending_captures_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<SyncStatus>? _syncSubscription;
  final _fabVisibility = FabVisibility();

  @override
  void initState() {
    super.initState();
    // Load dashboard data on init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _listenToSync();
      ref.read(walletCaptureProvider.notifier).refresh();
      await _askForAlertPermission();
      if (mounted) await _refresh();
    });
  }

  /// Refreshing the dashboard also adds repeating payments that came due,
  /// so the cards that list them reload after it.
  Future<void> _refresh() async {
    await ref.read(dashboardProvider.notifier).refresh();
    if (!mounted) return;
    ref.invalidate(recurringRulesProvider);
    ref.invalidate(goalsProvider);
  }

  /// Budget alerts are on by default, but Android 13 and later show nothing
  /// until the user allows notifications. Ask once Home opens, when the
  /// user has budgets to be alerted about. Android shows its dialog at most
  /// twice in total, so this does not keep nagging after a refusal.
  Future<void> _askForAlertPermission() async {
    final settings = ref.read(settingsProvider);
    if (!settings.notificationsEnabled || !settings.budgetAlertsEnabled) {
      return;
    }
    try {
      final budgets = await ref.read(budgetRepositoryProvider).getAll();
      if (budgets.every((b) => b.isDeleted)) return;
      final notifications = ref.read(notificationServiceProvider);
      if (await notifications.areEnabled()) return;
      await notifications.requestPermission();
    } catch (e) {
      debugPrint('Budget alert permission check failed: $e');
    }
  }

  void _listenToSync() {
    _syncSubscription =
        ref.read(syncEngineProvider).statusStream.listen((status) {
      if (status == SyncStatus.synced && mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _fabVisibility.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() => _refresh();

  @override
  Widget build(BuildContext context) {
    final dashboardData = ref.watch(dashboardProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      // Content scrolls under the glass app bar (and, through the shell,
      // under the navigation bar); the list's padding keeps it clear.
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Text('SpendSheet'),
        actions: [
          SyncIndicator(),
          SizedBox(width: Space.sm),
        ],
      ),
      body: _buildBody(context, dashboardData, currency),
      floatingActionButton: AutoHideFab(
        visibility: _fabVisibility,
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/transactions/add'),
          tooltip: 'Add transaction',
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DashboardData dashboardData,
    String currency,
  ) {
    return NotificationListener<UserScrollNotification>(
        onNotification: _fabVisibility.onScroll,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          // Show the spinner below the app bar, not behind it.
          edgeOffset: ScreenInsets.topOf(context),
          child: dashboardData.isLoading
              ? const Center(child: CircularProgressIndicator())
              : dashboardData.error != null
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
                          Text(
                            dashboardData.error!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.lg),
                          FilledButton(
                            onPressed: _handleRefresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: ScreenInsets.of(
                        context,
                        bottom: Space.fabClearance,
                      ),
                      children: [
                        const PendingCapturesBanner(),
                        MonthlySummaryCard(
                          income: dashboardData.monthlyIncome,
                          expense: dashboardData.monthlyExpense,
                          balance: dashboardData.monthlyBalance,
                          currency: currency,
                        ),
                        const SizedBox(height: Space.lg),
                        SpendingTrendChart(
                          dailySpending: dashboardData.weeklySpending,
                          currency: currency,
                        ),
                        const SizedBox(height: Space.lg),
                        BudgetProgressBars(
                          budgets: dashboardData.budgets,
                          onViewAll: () => context.go('/budgets'),
                          currency: currency,
                        ),
                        const SizedBox(height: Space.lg),
                        UpcomingPaymentsCard(currency: currency),
                        GoalsSummaryCard(currency: currency),
                        LoansSummaryCard(
                          totalOwedToYou: dashboardData.totalOwedToYou,
                          totalYouOwe: dashboardData.totalYouOwe,
                          onTap: () => context.push('/loans'),
                          currency: currency,
                        ),
                        const SizedBox(height: Space.lg),
                        RecentTransactionsList(
                          transactions: dashboardData.recentTransactions,
                          onViewAll: () => context.go('/transactions'),
                          onTap: (transaction) {
                            context
                                .push('/transactions/edit/${transaction.id}');
                          },
                          currency: currency,
                        ),
                      ],
                    ),
        ),
    );
  }
}
