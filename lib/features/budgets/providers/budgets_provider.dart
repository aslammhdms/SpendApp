import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/budget.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../home/providers/dashboard_provider.dart';

class BudgetsState {
  final List<Budget> budgets;
  final bool isLoading;
  final String? error;

  const BudgetsState({
    this.budgets = const [],
    this.isLoading = false,
    this.error,
  });

  BudgetsState copyWith({
    List<Budget>? budgets,
    bool? isLoading,
    String? error,
  }) {
    return BudgetsState(
      budgets: budgets ?? this.budgets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BudgetsNotifier extends StateNotifier<BudgetsState> {
  final BudgetRepository _repository;

  BudgetsNotifier(this._repository) : super(const BudgetsState());

  Future<void> loadBudgets() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final budgets = await _repository.getAll();
      state = state.copyWith(budgets: budgets, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load budgets: $e',
      );
    }
  }

  Future<void> createBudget({
    required String name,
    required double amount,
    required BudgetPeriod period,
    String? categoryId,
  }) async {
    try {
      await _repository.create(
        name: name,
        amount: amount,
        period: period,
        categoryId: categoryId,
      );
      await loadBudgets();
    } catch (e) {
      state = state.copyWith(error: 'Failed to create budget: $e');
      rethrow;
    }
  }

  Future<void> updateBudget(Budget budget) async {
    try {
      await _repository.update(budget);
      await loadBudgets();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update budget: $e');
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await _repository.delete(id);
      state = state.copyWith(
        budgets: state.budgets.where((b) => b.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete budget: $e');
      rethrow;
    }
  }
}

final budgetsProvider =
    StateNotifierProvider<BudgetsNotifier, BudgetsState>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  return BudgetsNotifier(repository);
});
