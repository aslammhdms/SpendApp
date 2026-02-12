import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category.dart';
import '../../../data/models/account.dart';
import '../../../data/remote/sync_engine.dart';
import '../providers/transactions_provider.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/filter_sheet.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsProvider.notifier).loadTransactions(refresh: true);
      _syncSubscription = ref.read(syncEngineProvider).statusStream.listen((status) {
        if (status == SyncStatus.synced && mounted) {
          ref.read(transactionsProvider.notifier).loadTransactions(refresh: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionsProvider.notifier).loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(transactionsProvider.notifier).loadTransactions(refresh: true);
  }

  void _showFilterSheet() async {
    final categories = await ref.read(categoriesProvider.future);
    final accounts = await ref.read(accountRepositoryProvider).getAll();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: FilterSheet(
            currentFilter: ref.read(transactionsProvider).filter,
            categories: categories,
            accounts: accounts,
            onApply: (filter) {
              ref.read(transactionsProvider.notifier).setFilter(filter);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  ref.read(transactionsProvider.notifier).setSearchQuery(query);
                },
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(transactionsProvider.notifier).setSearchQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: state.filter.hasFilters,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: state.isLoading && state.transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.transactions.isEmpty
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
                        onPressed: _handleRefresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : state.transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.filter.hasFilters
                                ? 'No transactions match your filters'
                                : 'No transactions yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          if (state.filter.hasFilters) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                ref.read(transactionsProvider.notifier).clearFilter();
                              },
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: categoriesAsync.when(
                        data: (categories) => _buildTransactionsList(
                          state,
                          categories,
                          currency: currency,
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, __) => _buildTransactionsList(state, [], currency: currency),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildTransactionsList(
    TransactionsState state,
    List<Category> categories, {
    String currency = 'USD',
  }) {
    final grouped = state.groupedByDate;
    final dateKeys = grouped.keys.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: dateKeys.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == dateKeys.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final dateKey = dateKeys[index];
        final transactions = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...transactions.map((transaction) {
              final category = categories.firstWhere(
                (c) => c.id == transaction.categoryId,
                orElse: () => Category(
                  id: '',
                  name: 'Unknown',
                  type: CategoryType.expense,
                  icon: '?',
                  color: 0xFF808080,
                  sortOrder: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

              return TransactionTile(
                transaction: transaction,
                category: category.id.isNotEmpty ? category : null,
                currency: currency,
                onTap: () => context.push('/transactions/edit/${transaction.id}'),
                onEdit: () => context.push('/transactions/edit/${transaction.id}'),
                onDelete: () => _confirmDelete(transaction.id),
              );
            }),
          ],
        );
      },
    );
  }

  void _confirmDelete(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(transactionsProvider.notifier).deleteTransaction(transactionId);
              Navigator.pop(context);
              ref.read(dashboardProvider.notifier).refresh();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
