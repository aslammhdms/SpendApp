import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';
import 'package:spendsheet/data/models/transaction.dart';

void main() {
  group('RecurringRule.calculateNextDueDate', () {
    RecurringRule makeRule({
      required RecurringFrequency frequency,
      required DateTime nextDueDate,
      int interval = 1,
    }) {
      final now = DateTime.now();
      return RecurringRule(
        id: 'test-id',
        name: 'Test Rule',
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        frequency: frequency,
        interval: interval,
        nextDueDate: nextDueDate,
        createdAt: now,
        updatedAt: now,
      );
    }

    group('daily', () {
      test('advances by interval days', () {
        final rule = makeRule(
          frequency: RecurringFrequency.daily,
          nextDueDate: DateTime(2025, 1, 15),
          interval: 3,
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 1, 18));
      });
    });

    group('weekly', () {
      test('advances by 7 * interval days', () {
        final rule = makeRule(
          frequency: RecurringFrequency.weekly,
          nextDueDate: DateTime(2025, 1, 1),
          interval: 2,
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 1, 15));
      });
    });

    group('monthly', () {
      test('normal month advance', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2025, 1, 15),
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 2, 15));
      });

      test('Jan 31 -> Feb 28 (non-leap year)', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2025, 1, 31),
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 2, 28));
      });

      test('Jan 31 -> Feb 29 (leap year)', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2024, 1, 31),
        );
        expect(rule.calculateNextDueDate(), DateTime(2024, 2, 29));
      });

      test('Jan 30 -> Feb 28 (non-leap year)', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2025, 1, 30),
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 2, 28));
      });

      test('Mar 31 -> Apr 30', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2025, 3, 31),
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 4, 30));
      });

      test('month advance across year boundary', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2025, 11, 15),
          interval: 3,
        );
        expect(rule.calculateNextDueDate(), DateTime(2026, 2, 15));
      });

      test('Dec 31 + 2 months -> Feb 28', () {
        final rule = makeRule(
          frequency: RecurringFrequency.monthly,
          nextDueDate: DateTime(2024, 12, 31),
          interval: 2,
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 2, 28));
      });
    });

    group('yearly', () {
      test('normal year advance', () {
        final rule = makeRule(
          frequency: RecurringFrequency.yearly,
          nextDueDate: DateTime(2025, 6, 15),
        );
        expect(rule.calculateNextDueDate(), DateTime(2026, 6, 15));
      });

      test('Feb 29 leap -> Feb 28 non-leap', () {
        final rule = makeRule(
          frequency: RecurringFrequency.yearly,
          nextDueDate: DateTime(2024, 2, 29),
        );
        expect(rule.calculateNextDueDate(), DateTime(2025, 2, 28));
      });

      test('Feb 29 leap -> Feb 29 next leap year (interval 4)', () {
        final rule = makeRule(
          frequency: RecurringFrequency.yearly,
          nextDueDate: DateTime(2024, 2, 29),
          interval: 4,
        );
        expect(rule.calculateNextDueDate(), DateTime(2028, 2, 29));
      });
    });
  });
}
