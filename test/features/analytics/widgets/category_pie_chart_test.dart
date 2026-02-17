import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/features/analytics/widgets/category_pie_chart.dart';
import 'package:spendsheet/features/transactions/providers/transactions_provider.dart';

void main() {
  Widget buildTestWidget({
    Map<String, double> categoryTotals = const {},
    double totalAmount = 0,
    String currency = 'USD',
    List<Category>? categories,
  }) {
    final cats = categories ?? [
      Category(
        id: 'cat_food', name: 'Food', type: CategoryType.expense,
        icon: '🍔', color: 0xFFFF6B6B, sortOrder: 0,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
      Category(
        id: 'cat_transport', name: 'Transport', type: CategoryType.expense,
        icon: '🚗', color: 0xFF45B7D1, sortOrder: 1,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
      Category(
        id: 'cat_shopping', name: 'Shopping', type: CategoryType.expense,
        icon: '🛍️', color: 0xFFFF8ED4, sortOrder: 2,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    ];

    return ProviderScope(
      overrides: [
        categoriesProvider.overrideWith((ref) async => cats),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryPieChart(
              categoryTotals: categoryTotals,
              totalAmount: totalAmount,
              currency: currency,
            ),
          ),
        ),
      ),
    );
  }

  group('CategoryPieChart', () {
    testWidgets('empty data shows "No spending data"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No spending data'), findsOneWidget);
    });

    testWidgets('renders chart when data provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        categoryTotals: {'cat_food': 100, 'cat_transport': 50},
        totalAmount: 150,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No spending data'), findsNothing);
      expect(find.text('Spending by Category'), findsOneWidget);
    });

    testWidgets('shows category names in legend', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        categoryTotals: {'cat_food': 100, 'cat_transport': 50},
        totalAmount: 150,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsWidgets);
      expect(find.text('Transport'), findsWidgets);
    });

    testWidgets('single category fills chart', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        categoryTotals: {'cat_food': 500},
        totalAmount: 500,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Spending by Category'), findsOneWidget);
      expect(find.text('100.0%'), findsWidgets);
    });

    testWidgets('more than 5 categories groups as Other', (tester) async {
      final categories = List.generate(7, (i) => Category(
        id: 'cat_$i', name: 'Cat $i', type: CategoryType.expense,
        icon: '📝', color: 0xFF000000 + (i * 0x111111), sortOrder: i,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      final totals = {for (int i = 0; i < 7; i++) 'cat_$i': 100.0};

      await tester.pumpWidget(buildTestWidget(
        categoryTotals: totals,
        totalAmount: 700,
        categories: categories,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Other'), findsWidgets);
    });
  });
}
