import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/features/transactions/services/category_order.dart';

Category _category(String id, int sortOrder) => Category(
      id: id,
      name: id,
      type: CategoryType.expense,
      icon: '📌',
      color: 0xFF6366F1,
      sortOrder: sortOrder,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  // In the order set in Settings.
  final categories = [
    _category('food', 0),
    _category('groceries', 1),
    _category('transport', 2),
    _category('pets', 3),
    _category('other', 4),
  ];

  List<String> order(Map<String, int> counts, {String? pinnedId}) =>
      orderCategoriesForQuickPick(categories, counts, pinnedId: pinnedId)
          .map((c) => c.id)
          .toList();

  test('keeps the set order when nothing has been used yet', () {
    expect(order({}), ['food', 'groceries', 'transport', 'pets', 'other']);
  });

  test('puts the most used categories first', () {
    expect(
      order({'other': 9, 'transport': 4}),
      ['other', 'transport', 'food', 'groceries', 'pets'],
    );
  });

  test('breaks ties by the set order', () {
    expect(
      order({'pets': 3, 'groceries': 3}),
      ['groceries', 'pets', 'food', 'transport', 'other'],
    );
  });

  test('shows the pinned category first, ahead of more used ones', () {
    expect(
      order({'food': 20, 'groceries': 5}, pinnedId: 'pets'),
      ['pets', 'food', 'groceries', 'transport', 'other'],
    );
  });

  test('ignores counts and pins for categories that are not listed', () {
    expect(
      order({'deleted': 50}, pinnedId: 'also-deleted'),
      ['food', 'groceries', 'transport', 'pets', 'other'],
    );
  });

  test('does not change the list it was given', () {
    final before = categories.map((c) => c.id).toList();

    order({'other': 9});

    expect(categories.map((c) => c.id).toList(), before);
  });
}
