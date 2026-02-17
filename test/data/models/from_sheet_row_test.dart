import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/models/account.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/data/models/person.dart';
import 'package:spendsheet/data/models/loan.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';

void main() {
  group('Transaction.fromSheetRow', () {
    test('parses valid 13-element row', () {
      final row = [
        'txn_1',
        '2024-06-15T10:30:00.000',
        '42.50',
        'expense',
        'cat_food',
        'acc_cash',
        'acc_bank',
        'Lunch',
        'receipt.jpg',
        'rule_1',
        '2024-06-15T10:30:00.000',
        '2024-06-15T10:30:00.000',
        '',
      ];
      final txn = Transaction.fromSheetRow(row);
      expect(txn.id, 'txn_1');
      expect(txn.amount, 42.50);
      expect(txn.type, TransactionType.expense);
      expect(txn.categoryId, 'cat_food');
      expect(txn.accountId, 'acc_cash');
      expect(txn.toAccountId, 'acc_bank');
      expect(txn.note, 'Lunch');
      expect(txn.receiptUrl, 'receipt.jpg');
      expect(txn.recurringId, 'rule_1');
      expect(txn.deletedAt, isNull);
    });

    test('pads short row', () {
      final row = ['txn_1', '2024-06-15T10:30:00.000', '100'];
      final txn = Transaction.fromSheetRow(row);
      expect(txn.id, 'txn_1');
      expect(txn.amount, 100.0);
    });

    test('empty strings map to null for optional fields', () {
      final row = [
        'txn_1', '2024-06-15T10:30:00.000', '100', 'expense',
        'cat_food', 'acc_cash', '', '', '', '',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final txn = Transaction.fromSheetRow(row);
      expect(txn.toAccountId, isNull);
      expect(txn.note, isNull);
      expect(txn.receiptUrl, isNull);
      expect(txn.recurringId, isNull);
      expect(txn.deletedAt, isNull);
    });

    test('unknown type falls back to expense', () {
      final row = [
        'txn_1', '2024-06-15T10:30:00.000', '100', 'unknown_type',
        'cat_food', 'acc_cash', '', '', '', '',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final txn = Transaction.fromSheetRow(row);
      expect(txn.type, TransactionType.expense);
    });

    test('invalid date falls back to DateTime.now()', () {
      final row = [
        'txn_1', 'not-a-date', '100', 'expense',
        'cat_food', 'acc_cash', '', '', '', '',
        'bad-date', 'bad-date', '',
      ];
      final before = DateTime.now();
      final txn = Transaction.fromSheetRow(row);
      final after = DateTime.now();
      // date should be roughly now
      expect(txn.date.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(txn.date.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('deletedAt parsed when non-empty', () {
      final row = [
        'txn_1', '2024-06-15T10:30:00.000', '100', 'expense',
        'cat_food', 'acc_cash', '', '', '', '',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000',
        '2024-07-01T00:00:00.000',
      ];
      final txn = Transaction.fromSheetRow(row);
      expect(txn.deletedAt, isNotNull);
      expect(txn.deletedAt!.month, 7);
    });
  });

  group('Account.fromSheetRow', () {
    test('parses valid 11-element row', () {
      final row = [
        'acc_1', 'My Bank', 'bank', '1000.0', 'USD',
        '🏦', '4283215615', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final acc = Account.fromSheetRow(row);
      expect(acc.id, 'acc_1');
      expect(acc.name, 'My Bank');
      expect(acc.type, AccountType.bank);
      expect(acc.initialBalance, 1000.0);
      expect(acc.currency, 'USD');
      expect(acc.icon, '🏦');
      expect(acc.deletedAt, isNull);
    });

    test('unknown type falls back to other', () {
      final row = [
        'acc_1', 'Crypto', 'crypto', '0', 'USD',
        '🪙', '0', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final acc = Account.fromSheetRow(row);
      expect(acc.type, AccountType.other);
    });

    test('bad color falls back to 0xFF808080', () {
      final row = [
        'acc_1', 'Bank', 'bank', '0', 'USD',
        '🏦', 'not-a-number', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final acc = Account.fromSheetRow(row);
      expect(acc.color, 0xFF808080);
    });

    test('missing currency defaults to USD', () {
      // row[4] as null
      final row = [
        'acc_1', 'Bank', 'bank', '0', null,
        '🏦', '0', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final acc = Account.fromSheetRow(row);
      expect(acc.currency, 'USD');
    });

    test('pads short row', () {
      final row = ['acc_1', 'Bank', 'bank'];
      final acc = Account.fromSheetRow(row);
      expect(acc.id, 'acc_1');
      expect(acc.name, 'Bank');
    });
  });

  group('Category.fromSheetRow', () {
    test('parses valid 9-element row', () {
      final row = [
        'cat_1', 'Food', 'expense', '🍔', '4294901760', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final cat = Category.fromSheetRow(row);
      expect(cat.id, 'cat_1');
      expect(cat.name, 'Food');
      expect(cat.type, CategoryType.expense);
      expect(cat.icon, '🍔');
      expect(cat.deletedAt, isNull);
    });

    test('unknown type falls back to expense', () {
      final row = [
        'cat_1', 'Other', 'special', '🔧', '0', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final cat = Category.fromSheetRow(row);
      expect(cat.type, CategoryType.expense);
    });

    test('bad color falls back to 0xFF808080', () {
      final row = [
        'cat_1', 'Food', 'expense', '🍔', 'bad', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final cat = Category.fromSheetRow(row);
      expect(cat.color, 0xFF808080);
    });

    test('income type parses correctly', () {
      final row = [
        'cat_sal', 'Salary', 'income', '💰', '4281549121', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final cat = Category.fromSheetRow(row);
      expect(cat.type, CategoryType.income);
    });

    test('deletedAt parsed when present', () {
      final row = [
        'cat_1', 'Food', 'expense', '🍔', '0', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000',
        '2024-07-01T00:00:00.000',
      ];
      final cat = Category.fromSheetRow(row);
      expect(cat.deletedAt, isNotNull);
    });
  });

  group('Budget.fromSheetRow', () {
    test('parses valid 9-element row', () {
      final row = [
        'bud_1', 'Food Budget', '500', 'monthly', 'cat_food',
        '2024-06-01T00:00:00.000',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final budget = Budget.fromSheetRow(row);
      expect(budget.id, 'bud_1');
      expect(budget.name, 'Food Budget');
      expect(budget.amount, 500.0);
      expect(budget.period, BudgetPeriod.monthly);
      expect(budget.categoryId, 'cat_food');
      expect(budget.deletedAt, isNull);
    });

    test('empty categoryId maps to null (overall budget)', () {
      final row = [
        'bud_1', 'Overall Budget', '2000', 'monthly', '',
        '2024-06-01T00:00:00.000',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final budget = Budget.fromSheetRow(row);
      expect(budget.categoryId, isNull);
      expect(budget.isOverall, isTrue);
    });

    test('unknown period falls back to monthly', () {
      final row = [
        'bud_1', 'Budget', '500', 'biweekly', 'cat_food',
        '2024-06-01T00:00:00.000',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final budget = Budget.fromSheetRow(row);
      expect(budget.period, BudgetPeriod.monthly);
    });

    test('weekly period parses correctly', () {
      final row = [
        'bud_1', 'Budget', '200', 'weekly', '',
        '2024-06-01T00:00:00.000',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(Budget.fromSheetRow(row).period, BudgetPeriod.weekly);
    });

    test('yearly period parses correctly', () {
      final row = [
        'bud_1', 'Budget', '5000', 'yearly', '',
        '2024-01-01T00:00:00.000',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(Budget.fromSheetRow(row).period, BudgetPeriod.yearly);
    });
  });

  group('Person.fromSheetRow', () {
    test('parses valid 7-element row', () {
      final row = [
        'per_1', 'John Doe', '555-1234', 'College friend',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final person = Person.fromSheetRow(row);
      expect(person.id, 'per_1');
      expect(person.name, 'John Doe');
      expect(person.phone, '555-1234');
      expect(person.note, 'College friend');
      expect(person.deletedAt, isNull);
    });

    test('empty phone and note map to null', () {
      final row = [
        'per_1', 'Jane', '', '',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final person = Person.fromSheetRow(row);
      expect(person.phone, isNull);
      expect(person.note, isNull);
    });

    test('short row pads correctly', () {
      final row = ['per_1', 'Bob'];
      final person = Person.fromSheetRow(row);
      expect(person.id, 'per_1');
      expect(person.name, 'Bob');
      expect(person.phone, isNull);
    });

    test('deletedAt parsed when present', () {
      final row = [
        'per_1', 'Jane', '', '',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000',
        '2024-07-01T00:00:00.000',
      ];
      final person = Person.fromSheetRow(row);
      expect(person.deletedAt, isNotNull);
    });
  });

  group('Loan.fromSheetRow', () {
    test('parses valid 10-element row', () {
      final row = [
        'loan_1', 'per_1', 'lent', '500', 'For rent',
        '2024-06-15T10:30:00.000', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final loan = Loan.fromSheetRow(row);
      expect(loan.id, 'loan_1');
      expect(loan.personId, 'per_1');
      expect(loan.type, LoanType.lent);
      expect(loan.amount, 500.0);
      expect(loan.note, 'For rent');
      expect(loan.isSettlement, isFalse);
      expect(loan.deletedAt, isNull);
    });

    test('isSettlement "1" maps to true, "0" maps to false', () {
      final rowSettlement = [
        'loan_1', 'per_1', 'borrowed', '500', '',
        '2024-06-15T10:30:00.000', '1',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(Loan.fromSheetRow(rowSettlement).isSettlement, isTrue);

      final rowNotSettlement = List<dynamic>.from(rowSettlement);
      rowNotSettlement[6] = '0';
      expect(Loan.fromSheetRow(rowNotSettlement).isSettlement, isFalse);
    });

    test('unknown type falls back to lent', () {
      final row = [
        'loan_1', 'per_1', 'gifted', '100', '',
        '2024-06-15T10:30:00.000', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final loan = Loan.fromSheetRow(row);
      expect(loan.type, LoanType.lent);
    });

    test('borrowed type parses correctly', () {
      final row = [
        'loan_1', 'per_1', 'borrowed', '300', '',
        '2024-06-15T10:30:00.000', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(Loan.fromSheetRow(row).type, LoanType.borrowed);
    });

    test('empty note maps to null', () {
      final row = [
        'loan_1', 'per_1', 'lent', '100', '',
        '2024-06-15T10:30:00.000', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(Loan.fromSheetRow(row).note, isNull);
    });
  });

  group('RecurringRule.fromSheetRow', () {
    test('parses valid 15-element row', () {
      final row = [
        'rule_1', 'Monthly Rent', '1000', 'expense', 'cat_bills', 'acc_bank',
        'monthly', '1', '2024-07-01T00:00:00.000', '', 'Rent payment', '1',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final rule = RecurringRule.fromSheetRow(row);
      expect(rule.id, 'rule_1');
      expect(rule.name, 'Monthly Rent');
      expect(rule.amount, 1000.0);
      expect(rule.type, TransactionType.expense);
      expect(rule.frequency, RecurringFrequency.monthly);
      expect(rule.interval, 1);
      expect(rule.note, 'Rent payment');
      expect(rule.isActive, isTrue);
      expect(rule.endDate, isNull);
      expect(rule.deletedAt, isNull);
    });

    test('isActive "0" maps to false', () {
      final row = [
        'rule_1', 'Rule', '100', 'expense', 'cat', 'acc',
        'daily', '1', '2024-07-01T00:00:00.000', '', '', '0',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(RecurringRule.fromSheetRow(row).isActive, isFalse);
    });

    test('interval parsed as int', () {
      final row = [
        'rule_1', 'Rule', '100', 'expense', 'cat', 'acc',
        'weekly', '3', '2024-07-01T00:00:00.000', '', '', '1',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(RecurringRule.fromSheetRow(row).interval, 3);
    });

    test('endDate parsed when non-empty', () {
      final row = [
        'rule_1', 'Rule', '100', 'expense', 'cat', 'acc',
        'monthly', '1', '2024-07-01T00:00:00.000',
        '2025-01-01T00:00:00.000', '', '1',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      final rule = RecurringRule.fromSheetRow(row);
      expect(rule.endDate, isNotNull);
      expect(rule.endDate!.year, 2025);
    });

    test('unknown frequency defaults to monthly', () {
      final row = [
        'rule_1', 'Rule', '100', 'expense', 'cat', 'acc',
        'biweekly', '1', '2024-07-01T00:00:00.000', '', '', '1',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(
          RecurringRule.fromSheetRow(row).frequency, RecurringFrequency.monthly);
    });

    test('unknown transaction type defaults to expense', () {
      final row = [
        'rule_1', 'Rule', '100', 'refund', 'cat', 'acc',
        'monthly', '1', '2024-07-01T00:00:00.000', '', '', '1',
        '2024-06-15T10:30:00.000', '2024-06-15T10:30:00.000', '',
      ];
      expect(RecurringRule.fromSheetRow(row).type, TransactionType.expense);
    });
  });
}
