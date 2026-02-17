import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';
import 'package:spendsheet/data/models/transaction.dart';

void main() {
  final now = DateTime(2024, 6, 15, 10, 30);

  RecurringRule _makeRule({
    String id = 'rule_1',
    String name = 'Monthly Rent',
    double amount = 1000.0,
    TransactionType type = TransactionType.expense,
    RecurringFrequency frequency = RecurringFrequency.monthly,
    int interval = 1,
    DateTime? nextDueDate,
    DateTime? endDate,
    String? note,
    bool isActive = true,
    DateTime? deletedAt,
  }) {
    return RecurringRule(
      id: id,
      name: name,
      amount: amount,
      type: type,
      categoryId: 'cat_bills',
      accountId: 'acc_bank',
      frequency: frequency,
      interval: interval,
      nextDueDate: nextDueDate ?? now,
      endDate: endDate,
      note: note,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
      deletedAt: deletedAt,
    );
  }

  group('RecurringRule', () {
    test('creates with all fields and defaults', () {
      final rule = _makeRule();
      expect(rule.interval, 1);
      expect(rule.isActive, isTrue);
      expect(rule.note, isNull);
      expect(rule.endDate, isNull);
    });

    test('isDeleted returns true when deletedAt set', () {
      final rule = _makeRule(deletedAt: now);
      expect(rule.isDeleted, isTrue);
    });

    test('isDue true when active and nextDueDate in past', () {
      final rule = _makeRule(
        nextDueDate: DateTime.now().subtract(const Duration(days: 1)),
        isActive: true,
      );
      expect(rule.isDue, isTrue);
    });

    test('isDue false when isActive is false', () {
      final rule = _makeRule(
        nextDueDate: DateTime.now().subtract(const Duration(days: 1)),
        isActive: false,
      );
      expect(rule.isDue, isFalse);
    });

    test('isDue false when nextDueDate in future', () {
      final rule = _makeRule(
        nextDueDate: DateTime.now().add(const Duration(days: 1)),
        isActive: true,
      );
      expect(rule.isDue, isFalse);
    });

    test('hasEnded true when endDate in past', () {
      final rule = _makeRule(
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(rule.hasEnded, isTrue);
    });

    test('hasEnded false when endDate is null', () {
      final rule = _makeRule(endDate: null);
      expect(rule.hasEnded, isFalse);
    });

    test('hasEnded false when endDate in future', () {
      final rule = _makeRule(
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(rule.hasEnded, isFalse);
    });

    test('copyWithDelete sets deletedAt', () {
      final rule = _makeRule();
      final deleted = rule.copyWithDelete();
      expect(deleted.isDeleted, isTrue);
      expect(deleted.id, rule.id);
    });

    test('toJson / fromJson roundtrip', () {
      final rule = _makeRule(note: 'Test note', interval: 2);
      final json = rule.toJson();
      final restored = RecurringRule.fromJson(json);
      expect(restored.id, rule.id);
      expect(restored.name, rule.name);
      expect(restored.amount, rule.amount);
      expect(restored.interval, 2);
      expect(restored.note, 'Test note');
      expect(restored.frequency, rule.frequency);
      expect(restored.isActive, rule.isActive);
    });

    test('toSheetRow / fromSheetRow roundtrip', () {
      final rule = _makeRule(
        note: 'Rent payment',
        interval: 1,
        isActive: true,
      );
      final sheetRow = rule.toSheetRow();
      final row = [
        sheetRow['id'],
        sheetRow['name'],
        sheetRow['amount'],
        sheetRow['type'],
        sheetRow['category_id'],
        sheetRow['account_id'],
        sheetRow['frequency'],
        sheetRow['interval'],
        sheetRow['next_due_date'],
        sheetRow['end_date'],
        sheetRow['note'],
        sheetRow['is_active'],
        sheetRow['created_at'],
        sheetRow['updated_at'],
        sheetRow['deleted_at'],
      ];
      final restored = RecurringRule.fromSheetRow(row);
      expect(restored.id, rule.id);
      expect(restored.name, rule.name);
      expect(restored.amount, rule.amount);
      expect(restored.type, rule.type);
      expect(restored.frequency, rule.frequency);
      expect(restored.interval, 1);
      expect(restored.note, 'Rent payment');
      expect(restored.isActive, isTrue);
    });

    test('fromSheetRow isActive parsing: "1" -> true, "0" -> false', () {
      final rowActive = [
        'id', 'name', '100', 'expense', 'cat', 'acc',
        'monthly', '1', '2024-06-15T00:00:00.000', '', 'note', '1',
        '2024-06-15T00:00:00.000', '2024-06-15T00:00:00.000', '',
      ];
      expect(RecurringRule.fromSheetRow(rowActive).isActive, isTrue);

      final rowInactive = List<dynamic>.from(rowActive);
      rowInactive[11] = '0';
      expect(RecurringRule.fromSheetRow(rowInactive).isActive, isFalse);
    });

    test('fromSheetRow unknown frequency defaults to monthly', () {
      final row = [
        'id', 'name', '100', 'expense', 'cat', 'acc',
        'biweekly', '1', '2024-06-15T00:00:00.000', '', '', '1',
        '2024-06-15T00:00:00.000', '2024-06-15T00:00:00.000', '',
      ];
      expect(RecurringRule.fromSheetRow(row).frequency,
          RecurringFrequency.monthly);
    });
  });
}
