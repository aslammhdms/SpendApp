import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../home/providers/dashboard_provider.dart';

class AccountsState {
  final List<Account> accounts;
  final double totalBalance;
  final bool isLoading;
  final String? error;

  const AccountsState({
    this.accounts = const [],
    this.totalBalance = 0,
    this.isLoading = false,
    this.error,
  });

  AccountsState copyWith({
    List<Account>? accounts,
    double? totalBalance,
    bool? isLoading,
    String? error,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      totalBalance: totalBalance ?? this.totalBalance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AccountsNotifier extends StateNotifier<AccountsState> {
  final AccountRepository _repository;

  AccountsNotifier(this._repository) : super(const AccountsState());

  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final accounts = await _repository.getAllWithBalances();
      final totalBalance = await _repository.getTotalBalance();
      state = state.copyWith(
        accounts: accounts,
        totalBalance: totalBalance,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load accounts: $e',
      );
    }
  }

  Future<void> createAccount({
    required String name,
    required AccountType type,
    required double initialBalance,
    required String currency,
    required String icon,
    required int color,
  }) async {
    try {
      await _repository.create(
        name: name,
        type: type,
        initialBalance: initialBalance,
        currency: currency,
        icon: icon,
        color: color,
      );
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(error: 'Failed to create account: $e');
      rethrow;
    }
  }

  Future<void> updateAccount(Account account) async {
    try {
      await _repository.update(account);
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update account: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _repository.delete(id);
      state = state.copyWith(
        accounts: state.accounts.where((a) => a.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete account: $e');
      rethrow;
    }
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, AccountsState>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return AccountsNotifier(repository);
});
