import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';
import 'package:spendsheet/data/repositories/category_repository.dart';
import 'package:spendsheet/features/home/providers/dashboard_provider.dart'
    show syncEngineProvider;
import 'package:spendsheet/features/transactions/providers/transactions_provider.dart';
import 'package:spendsheet/shared/widgets/sync_list_refresher.dart';

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockCategoryRepository extends Mock implements CategoryRepository {}

Category _category(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: '📌',
      color: 0xFF6366F1,
      sortOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late StreamController<SyncStatus> status;
  late _MockSyncEngine engine;
  late _MockCategoryRepository categories;
  late List<Category> stored;

  setUp(() {
    status = StreamController<SyncStatus>.broadcast();
    engine = _MockSyncEngine();
    when(() => engine.statusStream).thenAnswer((_) => status.stream);
    categories = _MockCategoryRepository();
    stored = [
      _category('old', 'Food & Dining'),
      _category('cat_food', 'Food & Dining'),
    ];
    when(() => categories.getExpenseCategories())
        .thenAnswer((_) async => List.of(stored));
  });

  tearDown(() => status.close());

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncEngineProvider.overrideWithValue(engine),
          categoryRepositoryProvider.overrideWithValue(categories),
        ],
        child: MaterialApp(
          home: SyncListRefresher(
            child: Consumer(
              builder: (context, ref, _) {
                final list = ref.watch(expenseCategoriesProvider);
                return Text('categories: ${list.valueOrNull?.length}');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a finished sync reloads the category list', (tester) async {
    await pumpList(tester);
    expect(find.text('categories: 2'), findsOneWidget);

    // Sync folds the duplicate away.
    stored.removeLast();
    status.add(SyncStatus.syncing);
    await tester.pumpAndSettle();
    expect(find.text('categories: 2'), findsOneWidget,
        reason: 'not reloaded while the sync is still running');

    status.add(SyncStatus.synced);
    await tester.pumpAndSettle();
    expect(find.text('categories: 1'), findsOneWidget);
  });

  testWidgets('other sync states leave the list alone', (tester) async {
    await pumpList(tester);
    stored.removeLast();

    for (final state in [SyncStatus.pending, SyncStatus.error, SyncStatus.idle]) {
      status.add(state);
      await tester.pumpAndSettle();
    }

    expect(find.text('categories: 2'), findsOneWidget);
    verify(() => categories.getExpenseCategories()).called(1);
  });
}
