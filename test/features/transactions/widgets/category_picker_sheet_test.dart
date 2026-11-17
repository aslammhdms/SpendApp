import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/constants/category_defaults.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/features/transactions/widgets/category_picker_sheet.dart';

void main() {
  final categories = [
    for (final (i, d) in CategoryDefaults.expenseCategories.indexed)
      Category(
        id: d.id,
        name: d.name,
        type: CategoryType.expense,
        icon: d.icon,
        color: d.color,
        sortOrder: i,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];

  /// Opens the picker from a button and records what it returns.
  Future<List<Category?>> openPicker(
    WidgetTester tester, {
    String? selectedId,
    Size size = const Size(412, 892),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final results = <Category?>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showCategoryPicker(
                  context,
                  categories: categories,
                  selectedId: selectedId,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('shows every category at once on a phone, the last included',
      (tester) async {
    await openPicker(tester);

    expect(tester.takeException(), isNull);
    for (final category in categories) {
      expect(find.text(category.name).hitTestable(), findsOneWidget,
          reason: '${category.name} should be reachable without scrolling');
    }
  });

  testWidgets('returns the category that is tapped and closes', (tester) async {
    final results = await openPicker(tester);

    await tester.tap(find.text('Other Expense'));
    await tester.pumpAndSettle();

    expect(results.single?.id, categories.last.id);
    expect(find.text('Choose category'), findsNothing);
  });

  testWidgets('search narrows the grid, ignoring case', (tester) async {
    await openPicker(tester);

    await tester.enterText(
        find.byKey(const Key('categorySearchField')), 'OTHER');
    await tester.pumpAndSettle();

    expect(find.text('Other Expense'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('says so when nothing matches the search', (tester) async {
    await openPicker(tester);

    await tester.enterText(
        find.byKey(const Key('categorySearchField')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No categories match'), findsOneWidget);
  });

  testWidgets('marks the current category as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await openPicker(tester, selectedId: categories[1].id);

    expect(
      tester.getSemantics(find.bySemanticsLabel(categories[1].name)),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(categories[0].name)),
      isSemantics(isSelected: false, isButton: true),
    );
    handle.dispose();
  });

  testWidgets('returns nothing when dismissed', (tester) async {
    final results = await openPicker(tester);

    await tester.tapAt(const Offset(200, 20)); // the scrim above the sheet
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('fits a small phone at 1.3x text without overflowing',
      (tester) async {
    await openPicker(tester, size: const Size(360, 640), textScale: 1.3);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Other Expense'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Other Expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
