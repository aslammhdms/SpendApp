import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/data/repositories/category_repository.dart';
import 'package:spendsheet/features/categories/providers/categories_provider.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

Category _makeCategory({
  String id = 'cat_1',
  String name = 'Food',
  CategoryType type = CategoryType.expense,
  int sortOrder = 0,
}) {
  final now = DateTime.now();
  return Category(
    id: id, name: name, type: type, icon: '🍔',
    color: 0xFFFF6B6B, sortOrder: sortOrder,
    createdAt: now, updatedAt: now,
  );
}

void main() {
  late MockCategoryRepository mockRepo;
  late CategoriesNotifier notifier;

  setUpAll(() {
    registerFallbackValue(_makeCategory());
    registerFallbackValue(<Category>[]);
    registerFallbackValue(CategoryType.expense);
  });

  setUp(() {
    mockRepo = MockCategoryRepository();
    notifier = CategoriesNotifier(mockRepo);
  });

  group('CategoriesNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state.expenseCategories, isEmpty);
      expect(notifier.state.incomeCategories, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });

    test('loadCategories fetches expense and income separately', () async {
      when(() => mockRepo.getExpenseCategories())
          .thenAnswer((_) async => [
                _makeCategory(id: 'cat_food', type: CategoryType.expense),
              ]);
      when(() => mockRepo.getIncomeCategories())
          .thenAnswer((_) async => [
                _makeCategory(
                    id: 'cat_salary',
                    name: 'Salary',
                    type: CategoryType.income),
              ]);

      await notifier.loadCategories();

      expect(notifier.state.expenseCategories.length, 1);
      expect(notifier.state.incomeCategories.length, 1);
      expect(notifier.state.isLoading, isFalse);
    });

    test('createCategory calls repo and reloads', () async {
      when(() => mockRepo.create(
            name: any(named: 'name'),
            type: any(named: 'type'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
          )).thenAnswer((_) async => _makeCategory());
      when(() => mockRepo.getExpenseCategories())
          .thenAnswer((_) async => [_makeCategory()]);
      when(() => mockRepo.getIncomeCategories())
          .thenAnswer((_) async => []);

      await notifier.createCategory(
        name: 'Food', type: CategoryType.expense,
        icon: '🍔', color: 0xFFFF6B6B,
      );

      verify(() => mockRepo.create(
            name: 'Food', type: CategoryType.expense,
            icon: '🍔', color: 0xFFFF6B6B,
          )).called(1);
    });

    test('updateCategory calls repo and reloads', () async {
      final cat = _makeCategory();
      when(() => mockRepo.update(any()))
          .thenAnswer((_) async => cat);
      when(() => mockRepo.getExpenseCategories())
          .thenAnswer((_) async => [cat]);
      when(() => mockRepo.getIncomeCategories())
          .thenAnswer((_) async => []);

      await notifier.updateCategory(cat);

      verify(() => mockRepo.update(cat)).called(1);
    });

    test('deleteCategory removes from both lists optimistically', () async {
      when(() => mockRepo.getExpenseCategories())
          .thenAnswer((_) async => [
                _makeCategory(id: 'cat_1'),
                _makeCategory(id: 'cat_2', name: 'Transport'),
              ]);
      when(() => mockRepo.getIncomeCategories())
          .thenAnswer((_) async => []);
      when(() => mockRepo.delete(any()))
          .thenAnswer((_) async {});

      await notifier.loadCategories();
      await notifier.deleteCategory('cat_1');

      expect(notifier.state.expenseCategories.length, 1);
      expect(notifier.state.expenseCategories.first.id, 'cat_2');
    });

    test('reorderCategories updates expense list', () async {
      final categories = [
        _makeCategory(id: 'cat_2', name: 'Transport', sortOrder: 0),
        _makeCategory(id: 'cat_1', name: 'Food', sortOrder: 1),
      ];
      when(() => mockRepo.reorder(any()))
          .thenAnswer((_) async {});

      await notifier.reorderCategories(categories, CategoryType.expense);

      expect(notifier.state.expenseCategories.length, 2);
      expect(notifier.state.expenseCategories.first.id, 'cat_2');
    });

    test('error sets error state', () async {
      when(() => mockRepo.getExpenseCategories())
          .thenThrow(Exception('Error'));

      await notifier.loadCategories();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
