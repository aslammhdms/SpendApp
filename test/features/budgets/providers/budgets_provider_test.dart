import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/data/repositories/budget_repository.dart';
import 'package:spendsheet/features/budgets/providers/budgets_provider.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

Budget _makeBudget({
  String id = 'bud_1',
  String name = 'Food',
  double amount = 500,
}) {
  final now = DateTime.now();
  return Budget(
    id: id, name: name, amount: amount,
    period: BudgetPeriod.monthly, startDate: now,
    createdAt: now, updatedAt: now,
  );
}

void main() {
  late MockBudgetRepository mockRepo;
  late BudgetsNotifier notifier;

  setUpAll(() {
    registerFallbackValue(BudgetPeriod.monthly);
    registerFallbackValue(_makeBudget());
  });

  setUp(() {
    mockRepo = MockBudgetRepository();
    notifier = BudgetsNotifier(mockRepo);
  });

  group('BudgetsNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state.budgets, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('loadBudgets populates state', () async {
      final budgets = [_makeBudget(id: 'bud_1'), _makeBudget(id: 'bud_2')];
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => budgets);

      await notifier.loadBudgets();

      expect(notifier.state.budgets.length, 2);
      expect(notifier.state.isLoading, isFalse);
    });

    test('createBudget calls repo and reloads', () async {
      when(() => mockRepo.create(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            period: any(named: 'period'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => _makeBudget());
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [_makeBudget()]);

      await notifier.createBudget(
        name: 'Food',
        amount: 500,
        period: BudgetPeriod.monthly,
      );

      verify(() => mockRepo.create(
            name: 'Food',
            amount: 500,
            period: BudgetPeriod.monthly,
            categoryId: null,
          )).called(1);
      expect(notifier.state.budgets.length, 1);
    });

    test('updateBudget calls repo and reloads', () async {
      final budget = _makeBudget();
      when(() => mockRepo.update(any()))
          .thenAnswer((_) async => budget);
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [budget]);

      await notifier.updateBudget(budget);

      verify(() => mockRepo.update(budget)).called(1);
    });

    test('deleteBudget removes optimistically', () async {
      final budgets = [_makeBudget(id: 'bud_1'), _makeBudget(id: 'bud_2')];
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => budgets);
      when(() => mockRepo.delete(any()))
          .thenAnswer((_) async {});

      await notifier.loadBudgets();
      await notifier.deleteBudget('bud_1');

      expect(notifier.state.budgets.length, 1);
      expect(notifier.state.budgets.first.id, 'bud_2');
    });

    test('error sets error state', () async {
      when(() => mockRepo.getAll())
          .thenThrow(Exception('DB error'));

      await notifier.loadBudgets();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
