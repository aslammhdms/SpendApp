import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/budget.dart';

void main() {
  final now = DateTime(2024, 6, 15, 10, 30);

  Budget _makeBudget({
    String id = 'budget_1',
    String name = 'Food Budget',
    double amount = 500.0,
    double spentAmount = 0.0,
    BudgetPeriod period = BudgetPeriod.monthly,
    String? categoryId = 'cat_food',
    DateTime? deletedAt,
  }) {
    return Budget(
      id: id,
      name: name,
      amount: amount,
      period: period,
      categoryId: categoryId,
      startDate: now,
      createdAt: now,
      updatedAt: now,
      deletedAt: deletedAt,
      spentAmount: spentAmount,
    );
  }

  group('Budget', () {
    test('creates with all fields', () {
      final budget = _makeBudget();
      expect(budget.id, 'budget_1');
      expect(budget.name, 'Food Budget');
      expect(budget.amount, 500.0);
      expect(budget.period, BudgetPeriod.monthly);
      expect(budget.categoryId, 'cat_food');
      expect(budget.spentAmount, 0.0);
    });

    test('isDeleted returns true when deletedAt is set', () {
      final budget = _makeBudget(deletedAt: now);
      expect(budget.isDeleted, isTrue);
    });

    test('isDeleted returns false when deletedAt is null', () {
      final budget = _makeBudget();
      expect(budget.isDeleted, isFalse);
    });

    test('isOverall returns true when categoryId is null', () {
      final budget = _makeBudget(categoryId: null);
      expect(budget.isOverall, isTrue);
    });

    test('isOverall returns false when categoryId is set', () {
      final budget = _makeBudget(categoryId: 'cat_food');
      expect(budget.isOverall, isFalse);
    });

    test('remaining calculation', () {
      final budget = _makeBudget(amount: 500, spentAmount: 200);
      expect(budget.remaining, 300.0);
    });

    test('remaining negative when over budget', () {
      final budget = _makeBudget(amount: 500, spentAmount: 600);
      expect(budget.remaining, -100.0);
    });

    test('percentUsed normal case', () {
      final budget = _makeBudget(amount: 500, spentAmount: 250);
      expect(budget.percentUsed, 0.5);
    });

    test('percentUsed zero amount guard returns 0', () {
      final budget = _makeBudget(amount: 0, spentAmount: 100);
      expect(budget.percentUsed, 0);
    });

    test('isOverBudget true when spent > amount', () {
      final budget = _makeBudget(amount: 500, spentAmount: 600);
      expect(budget.isOverBudget, isTrue);
    });

    test('isOverBudget false when spent <= amount', () {
      final budget = _makeBudget(amount: 500, spentAmount: 500);
      expect(budget.isOverBudget, isFalse);
    });

    test('isWarning true at 80-99%', () {
      final budget = _makeBudget(amount: 500, spentAmount: 400); // 80%
      expect(budget.isWarning, isTrue);
    });

    test('isWarning true at 95%', () {
      final budget = _makeBudget(amount: 500, spentAmount: 475);
      expect(budget.isWarning, isTrue);
    });

    test('isWarning false below 80%', () {
      final budget = _makeBudget(amount: 500, spentAmount: 350); // 70%
      expect(budget.isWarning, isFalse);
    });

    test('isWarning false at 100%', () {
      final budget = _makeBudget(amount: 500, spentAmount: 500); // 100%
      expect(budget.isWarning, isFalse);
    });

    test('copyWithDelete sets deletedAt', () {
      final budget = _makeBudget();
      final deleted = budget.copyWithDelete();
      expect(deleted.isDeleted, isTrue);
      expect(deleted.id, budget.id);
    });

    test('toJson / fromJson roundtrip', () {
      final budget = _makeBudget(spentAmount: 200);
      final json = budget.toJson();
      final restored = Budget.fromJson(json);
      expect(restored.id, budget.id);
      expect(restored.name, budget.name);
      expect(restored.amount, budget.amount);
      expect(restored.period, budget.period);
      expect(restored.categoryId, budget.categoryId);
    });

    test('toSheetRow / fromSheetRow roundtrip', () {
      final budget = _makeBudget();
      final sheetRow = budget.toSheetRow();
      final row = [
        sheetRow['id'],
        sheetRow['name'],
        sheetRow['amount'],
        sheetRow['period'],
        sheetRow['category_id'],
        sheetRow['start_date'],
        sheetRow['created_at'],
        sheetRow['updated_at'],
        sheetRow['deleted_at'],
      ];
      final restored = Budget.fromSheetRow(row);
      expect(restored.id, budget.id);
      expect(restored.name, budget.name);
      expect(restored.amount, budget.amount);
      expect(restored.period, budget.period);
      expect(restored.categoryId, budget.categoryId);
    });
  });
}
