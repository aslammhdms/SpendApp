import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../home/providers/dashboard_provider.dart';

class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final String? searchQuery;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.searchQuery,
  });

  TransactionFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    double? minAmount,
    double? maxAmount,
    String? searchQuery,
  }) {
    return TransactionFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  TransactionFilter clearField(String field) {
    switch (field) {
      case 'startDate':
        return TransactionFilter(
          endDate: endDate,
          categoryId: categoryId,
          accountId: accountId,
          type: type,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
        );
      case 'endDate':
        return TransactionFilter(
          startDate: startDate,
          categoryId: categoryId,
          accountId: accountId,
          type: type,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
        );
      case 'categoryId':
        return TransactionFilter(
          startDate: startDate,
          endDate: endDate,
          accountId: accountId,
          type: type,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
        );
      case 'accountId':
        return TransactionFilter(
          startDate: startDate,
          endDate: endDate,
          categoryId: categoryId,
          type: type,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
        );
      case 'type':
        return TransactionFilter(
          startDate: startDate,
          endDate: endDate,
          categoryId: categoryId,
          accountId: accountId,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
        );
      default:
        return this;
    }
  }

  bool get hasFilters =>
      startDate != null ||
      endDate != null ||
      categoryId != null ||
      accountId != null ||
      type != null ||
      minAmount != null ||
      maxAmount != null ||
      (searchQuery?.isNotEmpty ?? false);

  TransactionFilter clear() => const TransactionFilter();
}

class TransactionsState {
  final List<Transaction> transactions;
  final TransactionFilter filter;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final bool hasMore;

  const TransactionsState({
    this.transactions = const [],
    this.filter = const TransactionFilter(),
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
    this.hasMore = true,
  });

  TransactionsState copyWith({
    List<Transaction>? transactions,
    TransactionFilter? filter,
    bool? isLoading,
    String? error,
    int? currentPage,
    bool? hasMore,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  Map<String, List<Transaction>> get groupedByDate {
    final grouped = <String, List<Transaction>>{};
    for (final transaction in transactions) {
      final dateKey = _getDateKey(transaction.date);
      grouped.putIfAbsent(dateKey, () => []).add(transaction);
    }
    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(transactionDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return 'This Week';
    if (difference < 30) return 'This Month';
    return '${date.month}/${date.year}';
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final TransactionRepository _repository;
  static const int _pageSize = 50;

  TransactionsNotifier(this._repository) : super(const TransactionsState());

  Future<void> loadTransactions({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 0 : state.currentPage,
      transactions: refresh ? [] : state.transactions,
    );

    try {
      List<Transaction> transactions;

      if (state.filter.hasFilters) {
        transactions = await _loadFilteredTransactions();
      } else {
        final offset = refresh ? 0 : state.currentPage * _pageSize;
        transactions = await _repository.getPaginated(offset, _pageSize);
      }

      // Apply search filter if present
      if (state.filter.searchQuery?.isNotEmpty ?? false) {
        final query = state.filter.searchQuery!.toLowerCase();
        transactions = transactions.where((t) {
          return t.note?.toLowerCase().contains(query) ?? false;
        }).toList();
      }

      final hasMore = transactions.length >= _pageSize;

      state = state.copyWith(
        transactions: refresh
            ? transactions
            : [...state.transactions, ...transactions],
        isLoading: false,
        currentPage: refresh ? 1 : state.currentPage + 1,
        hasMore: hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load transactions: $e',
      );
    }
  }

  Future<List<Transaction>> _loadFilteredTransactions() async {
    final filter = state.filter;
    List<Transaction> transactions;

    if (filter.startDate != null && filter.endDate != null) {
      transactions = await _repository.getByDateRange(
        filter.startDate!,
        filter.endDate!,
      );
    } else if (filter.categoryId != null) {
      transactions = await _repository.getByCategory(filter.categoryId!);
    } else if (filter.accountId != null) {
      transactions = await _repository.getByAccount(filter.accountId!);
    } else if (filter.type != null) {
      transactions = await _repository.getByType(filter.type!);
    } else {
      transactions = await _repository.getAll();
    }

    // Apply additional filters
    return transactions.where((t) {
      if (filter.minAmount != null && t.amount < filter.minAmount!) {
        return false;
      }
      if (filter.maxAmount != null && t.amount > filter.maxAmount!) {
        return false;
      }
      if (filter.type != null && t.type != filter.type) {
        return false;
      }
      if (filter.categoryId != null && t.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.accountId != null &&
          t.accountId != filter.accountId &&
          t.toAccountId != filter.accountId) {
        return false;
      }
      return true;
    }).toList();
  }

  void setFilter(TransactionFilter filter) {
    state = state.copyWith(filter: filter);
    loadTransactions(refresh: true);
  }

  void clearFilter() {
    state = state.copyWith(filter: const TransactionFilter());
    loadTransactions(refresh: true);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query),
    );
    loadTransactions(refresh: true);
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.delete(id);
      state = state.copyWith(
        transactions: state.transactions.where((t) => t.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete transaction: $e');
    }
  }

  void loadMore() {
    if (!state.isLoading && state.hasMore) {
      loadTransactions();
    }
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return TransactionsNotifier(repository);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    localDao: ref.watch(localCategoryDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return await repository.getAll();
});

final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return await repository.getExpenseCategories();
});

final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return await repository.getIncomeCategories();
});
