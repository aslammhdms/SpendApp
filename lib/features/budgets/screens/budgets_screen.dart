import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category.dart';
import '../../../data/remote/sync_engine.dart';
import '../providers/budgets_provider.dart';
import '../widgets/budget_card.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../settings/providers/settings_provider.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(budgetsProvider.notifier).loadBudgets();
      _syncSubscription = ref.read(syncEngineProvider).statusStream.listen((status) {
        if (status == SyncStatus.synced && mounted) {
          ref.read(budgetsProvider.notifier).loadBudgets();
        }
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
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
                      Text(state.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(budgetsProvider.notifier).loadBudgets();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : state.budgets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No budgets yet',
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a budget to track your spending',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/budgets/add'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Budget'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(budgetsProvider.notifier).loadBudgets();
                      },
                      child: categoriesAsync.when(
                        data: (categories) => _buildBudgetsList(
                          state,
                          categories,
                          currency: currency,
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, __) => _buildBudgetsList(state, [], currency: currency),
                      ),
                    ),
      floatingActionButton: state.budgets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/budgets/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Widget _buildBudgetsList(BudgetsState state, List<Category> categories, {String currency = 'USD'}) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.budgets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final budget = state.budgets[index];
        final category = categories.firstWhere(
          (c) => c.id == budget.categoryId,
          orElse: () => Category(
            id: '',
            name: 'Overall',
            type: CategoryType.expense,
            icon: '',
            color: 0xFF6366F1,
            sortOrder: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return BudgetCard(
          budget: budget,
          categoryIcon: category.id.isNotEmpty ? category.icon : null,
          currency: currency,
          onEdit: () => context.push('/budgets/edit/${budget.id}'),
          onDelete: () => _confirmDelete(budget.id),
        );
      },
    );
  }

  void _confirmDelete(String budgetId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(budgetsProvider.notifier).deleteBudget(budgetId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
