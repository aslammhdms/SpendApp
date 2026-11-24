import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/loan.dart';
import '../../../data/remote/sync_engine.dart';
import '../providers/transactions_provider.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/filter_sheet.dart';
import '../../../shared/widgets/auto_hide_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../shared/widgets/glass_sheet.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_dialog.dart';

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
  final _fabVisibility = FabVisibility();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsProvider.notifier).loadTransactions(refresh: true);
      _syncSubscription =
          ref.read(syncEngineProvider).statusStream.listen((status) {
        if (status == SyncStatus.synced && mounted) {
          ref
              .read(transactionsProvider.notifier)
              .loadTransactions(refresh: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _fabVisibility.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionsProvider.notifier).loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    await ref
        .read(transactionsProvider.notifier)
        .loadTransactions(refresh: true);
  }

  void _showFilterSheet() async {
    final categories = await ref.read(categoriesProvider.future);
    final accounts = await ref.read(accountRepositoryProvider).getAll();
    final labels = await ref.read(transactionRepositoryProvider).getAllLabels();

    if (!mounted) return;

    showAppSheet(
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
            labels: labels,
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
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
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
            tooltip: _showSearch ? 'Close search' : 'Search',
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
            tooltip: 'Filter',
            onPressed: _showFilterSheet,
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: state.isLoading && state.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.isEmpty
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
                      Text(state.error!),
                      const SizedBox(height: Space.lg),
                      FilledButton(
                        onPressed: _handleRefresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : state.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: state.filter.hasFilters
                          ? 'No transactions match your filters'
                          : 'No transactions yet',
                      action: state.filter.hasFilters
                          ? TextButton(
                              onPressed: () {
                                ref
                                    .read(transactionsProvider.notifier)
                                    .clearFilter();
                              },
                              child: const Text('Clear Filters'),
                            )
                          : null,
                    )
                  : NotificationListener<UserScrollNotification>(
                      onNotification: _fabVisibility.onScroll,
                      child: RefreshIndicator(
                        onRefresh: _handleRefresh,
                        edgeOffset: ScreenInsets.topOf(context),
                        child: categoriesAsync.when(
                          data: (categories) => _buildList(
                            state,
                            categories,
                            currency: currency,
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (_, __) =>
                              _buildList(state, [], currency: currency),
                        ),
                      ),
                    ),
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

  Widget _buildList(
    TransactionsState state,
    List<Category> categories, {
    String currency = 'USD',
  }) {
    final grouped = state.groupedByDate;
    final dateKeys = grouped.keys.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: ScreenInsets.of(
        context,
        top: 0,
        bottom: Space.fabClearance,
      ),
      itemCount: dateKeys.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == dateKeys.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final dateKey = dateKeys[index];
        final items = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OverlineHeader(dateKey),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Column(
                  children: [
                    ...items.map((item) {
                      if (item is Transaction) {
                        return _buildTransactionItem(
                            item, categories, currency);
                      } else if (item is Loan) {
                        return _buildLoanItem(item, state, currency);
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(
    Transaction transaction,
    List<Category> categories,
    String currency,
  ) {
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
      onTap: () => context.push('/transactions/edit/${Uri.encodeComponent(transaction.id)}'),
      onEdit: () => context.push('/transactions/edit/${Uri.encodeComponent(transaction.id)}'),
      onDelete: () => _confirmDeleteTransaction(transaction.id),
    );
  }

  Widget _buildLoanItem(Loan loan, TransactionsState state, String currency) {
    final personName = state.loanPersonNames[loan.personId] ?? 'Unknown';

    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    final (String subtitle, IconData icon, String prefix, Color amountColor) =
        loan.isSettlement
            ? ('Settlement', Icons.check_circle_outline, '', scheme.onSurface)
            : loan.isLent
                ? ('Lent', Icons.north_east_rounded, '-', scheme.onSurface)
                : ('Borrowed', Icons.south_west_rounded, '+', palette.loan);
    final secondary = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _confirmDeleteLoan(loan.id),
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/loans/person/${Uri.encodeComponent(loan.personId)}'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: Sizes.iconCircle,
                  height: Sizes.iconCircle,
                  decoration: BoxDecoration(
                    color: palette.loanContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: palette.onLoanContainer, size: Sizes.icon),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personName,
                        style: text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(subtitle, style: secondary),
                          if (loan.note?.isNotEmpty ?? false) ...[
                            Text(' • ', style: secondary),
                            Flexible(
                              child: Text(
                                loan.note!,
                                style: secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          Text(' • ', style: secondary),
                          Text(
                            AppDateUtils.formatDisplayTime(loan.date),
                            style: secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                MoneyText(
                  loan.amount,
                  currency: currency,
                  kind: MoneyKind.loan,
                  prefix: prefix,
                  semanticLabel: subtitle,
                  color: amountColor,
                  style: text.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTransaction(String transactionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Delete Transaction'),
        content:
            const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(transactionsProvider.notifier)
                  .deleteTransaction(transactionId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              ref.read(dashboardProvider.notifier).refresh();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLoan(String loanId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Delete Loan'),
        content: const Text('Are you sure you want to delete this loan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(transactionsProvider.notifier).deleteLoan(loanId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              ref.read(syncEngineProvider).sync();
              ref.read(dashboardProvider.notifier).refresh();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
