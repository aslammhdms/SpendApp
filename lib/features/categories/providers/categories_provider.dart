import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';
import '../../home/providers/dashboard_provider.dart';

class CategoriesState {
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final bool isLoading;
  final String? error;

  const CategoriesState({
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoriesState copyWith({
    List<Category>? expenseCategories,
    List<Category>? incomeCategories,
    bool? isLoading,
    String? error,
  }) {
    return CategoriesState(
      expenseCategories: expenseCategories ?? this.expenseCategories,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final CategoryRepository _repository;

  CategoriesNotifier(this._repository) : super(const CategoriesState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final expense = await _repository.getExpenseCategories();
      final income = await _repository.getIncomeCategories();
      state = state.copyWith(
        expenseCategories: expense,
        incomeCategories: income,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load categories: $e',
      );
    }
  }

  Future<void> createCategory({
    required String name,
    required CategoryType type,
    required String icon,
    required int color,
  }) async {
    try {
      await _repository.create(
        name: name,
        type: type,
        icon: icon,
        color: color,
      );
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: 'Failed to create category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _repository.update(category);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.delete(id);
      state = state.copyWith(
        expenseCategories:
            state.expenseCategories.where((c) => c.id != id).toList(),
        incomeCategories:
            state.incomeCategories.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete category: $e');
      rethrow;
    }
  }

  Future<void> reorderCategories(
    List<Category> categories,
    CategoryType type,
  ) async {
    try {
      await _repository.reorder(categories);
      if (type == CategoryType.expense) {
        state = state.copyWith(expenseCategories: categories);
      } else {
        state = state.copyWith(incomeCategories: categories);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to reorder: $e');
    }
  }
}

final categoriesManagerProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoriesNotifier(repository);
});
