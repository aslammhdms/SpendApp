import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/models/loan.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/loan_repository.dart';
import '../../../data/repositories/person_repository.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../loans/providers/loans_provider.dart';
import '../services/category_order.dart';

class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final String? searchQuery;
  final bool showLoansOnly;

  /// Only transactions carrying this label (ignoring case).
  final String? label;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.searchQuery,
    this.showLoansOnly = false,
    this.label,
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
    bool? showLoansOnly,
    String? label,
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
      showLoansOnly: showLoansOnly ?? this.showLoansOnly,
      label: label ?? this.label,
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
          showLoansOnly: showLoansOnly,
          label: label,
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
          showLoansOnly: showLoansOnly,
          label: label,
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
          showLoansOnly: showLoansOnly,
          label: label,
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
          showLoansOnly: showLoansOnly,
          label: label,
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
          showLoansOnly: showLoansOnly,
          label: label,
        );
      case 'showLoansOnly':
        return TransactionFilter(
          startDate: startDate,
          endDate: endDate,
          categoryId: categoryId,
          accountId: accountId,
          type: type,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
          showLoansOnly: false,
          label: label,
        );
      case 'label':
        return TransactionFilter(
          startDate: startDate,
          endDate: endDate,
          categoryId: categoryId,
          accountId: accountId,
          type: type,
          minAmount: minAmount,
          maxAmount: maxAmount,
          searchQuery: searchQuery,
          showLoansOnly: showLoansOnly,
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
      showLoansOnly ||
      label != null ||
      (searchQuery?.isNotEmpty ?? false);

  TransactionFilter clear() => const TransactionFilter();
}

class TransactionsState {
  final List<Transaction> transactions;
  final List<Loan> loans;
  final Map<String, String> loanPersonNames;
  final TransactionFilter filter;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final bool hasMore;

  const TransactionsState({
    this.transactions = const [],
    this.loans = const [],
    this.loanPersonNames = const {},
    this.filter = const TransactionFilter(),
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
    this.hasMore = true,
  });

  TransactionsState copyWith({
    List<Transaction>? transactions,
    List<Loan>? loans,
    Map<String, String>? loanPersonNames,
    TransactionFilter? filter,
    bool? isLoading,
    String? error,
    int? currentPage,
    bool? hasMore,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      loans: loans ?? this.loans,
      loanPersonNames: loanPersonNames ?? this.loanPersonNames,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  /// Returns items grouped by date. Each item is either a [Transaction] or [Loan].
  Map<String, List<Object>> get groupedByDate {
    final grouped = <String, List<Object>>{};

    // When showLoansOnly: only include loans
    // When type filter is set (expense/income/transfer): only include transactions
    // Otherwise: include both
    if (!filter.showLoansOnly) {
      for (final transaction in transactions) {
        final dateKey = _getDateKey(transaction.date);
        grouped.putIfAbsent(dateKey, () => []).add(transaction);
      }
    }

    if (filter.showLoansOnly || filter.type == null) {
      for (final loan in loans) {
        final dateKey = _getDateKey(loan.date);
        grouped.putIfAbsent(dateKey, () => []).add(loan);
      }
    }

    // Sort items within each group by date descending
    for (final items in grouped.values) {
      items.sort((a, b) {
        final dateA = a is Transaction ? a.date : (a as Loan).date;
        final dateB = b is Transaction ? b.date : (b as Loan).date;
        return dateB.compareTo(dateA);
      });
    }

    return grouped;
  }

  bool get isEmpty => transactions.isEmpty && loans.isEmpty;

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(itemDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return 'This Week';
    if (difference < 30) return 'This Month';
    return '${date.month}/${date.year}';
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final TransactionRepository _repository;
  final LoanRepository _loanRepo;
  final PersonRepository _personRepo;
  static const int _pageSize = 50;

  TransactionsNotifier(
    this._repository, {
    required LoanRepository loanRepo,
    required PersonRepository personRepo,
  })  : _loanRepo = loanRepo,
        _personRepo = personRepo,
        super(const TransactionsState());

  Future<void> loadTransactions({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 0 : state.currentPage,
      transactions: refresh ? [] : state.transactions,
      loans: refresh ? [] : state.loans,
    );

    try {
      List<Transaction> transactions = [];

      // Skip loading transactions when showing loans only
      if (!state.filter.showLoansOnly) {
        if (state.filter.hasFilters && !state.filter.showLoansOnly) {
          transactions = await _loadFilteredTransactions();
        } else {
          final offset = refresh ? 0 : state.currentPage * _pageSize;
          transactions = await _repository.getPaginated(offset, _pageSize);
        }

        // Apply search filter if present
        if (state.filter.searchQuery?.isNotEmpty ?? false) {
          final query = state.filter.searchQuery!.toLowerCase();
          transactions = transactions.where((t) {
            return (t.note?.toLowerCase().contains(query) ?? false) ||
                t.labels.any((l) => l.toLowerCase().contains(query));
          }).toList();
        }
      }

      final hasMore = transactions.length >= _pageSize;

      // Load loans and person names
      final allLoans = await _loanRepo.getAll();
      final people = await _personRepo.getAll();
      final personNames = {for (final p in people) p.id: p.name};

      state = state.copyWith(
        transactions: refresh
            ? transactions
            : [...state.transactions, ...transactions],
        loans: allLoans,
        loanPersonNames: personNames,
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

    if (filter.label != null) {
      transactions = await _repository.getByLabel(
        filter.label!,
        start: filter.startDate,
        end: filter.endDate,
      );
    } else if (filter.startDate != null && filter.endDate != null) {
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

  Future<void> deleteLoan(String id) async {
    try {
      await _loanRepo.delete(id);
      state = state.copyWith(
        loans: state.loans.where((l) => l.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete loan: $e');
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
  final loanRepo = ref.watch(loanRepositoryProvider);
  final personRepo = ref.watch(personRepositoryProvider);
  return TransactionsNotifier(
    repository,
    loanRepo: loanRepo,
    personRepo: personRepo,
  );
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

/// How often each category was used lately, for putting the usual ones
/// first when adding a transaction. Read again each time it is needed.
final categoryUseCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final since = DateTime.now().subtract(categoryUseWindow);
  return await repository.getCategoryUseCounts(since);
});
