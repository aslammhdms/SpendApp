import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/category.dart';

void main() {
  group('Category', () {
    final now = DateTime.now();

    test('creates expense category correctly', () {
      final category = Category(
        id: 'cat-1',
        name: 'Food',
        type: CategoryType.expense,
        icon: 'restaurant',
        color: 0xFFFF5722,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(category.id, equals('cat-1'));
      expect(category.name, equals('Food'));
      expect(category.type, equals(CategoryType.expense));
    });

    test('creates income category correctly', () {
      final category = Category(
        id: 'cat-2',
        name: 'Salary',
        type: CategoryType.income,
        icon: 'work',
        color: 0xFF4CAF50,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(category.type, equals(CategoryType.income));
    });

    test('copyWith creates new instance', () {
      final original = Category(
        id: 'cat-1',
        name: 'Food',
        type: CategoryType.expense,
        icon: 'restaurant',
        color: 0xFFFF5722,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'Groceries');

      expect(updated.name, equals('Groceries'));
      expect(original.name, equals('Food'));
    });

    test('toJson and fromJson roundtrip', () {
      final category = Category(
        id: 'cat-1',
        name: 'Food',
        type: CategoryType.expense,
        icon: 'restaurant',
        color: 0xFFFF5722,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final json = category.toJson();
      final restored = Category.fromJson(json);

      expect(restored.id, equals(category.id));
      expect(restored.name, equals(category.name));
      expect(restored.type, equals(category.type));
    });
  });

  group('CategoryType', () {
    test('has correct values', () {
      expect(CategoryType.values.length, equals(2));
      expect(CategoryType.expense.name, equals('expense'));
      expect(CategoryType.income.name, equals('income'));
    });
  });
}
