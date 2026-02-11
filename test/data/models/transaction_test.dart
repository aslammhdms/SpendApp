import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/transaction.dart';

void main() {
  group('Transaction', () {
    final now = DateTime.now();

    test('creates expense transaction correctly', () {
      final transaction = Transaction(
        id: 'test-id',
        date: now,
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(transaction.id, equals('test-id'));
      expect(transaction.amount, equals(50.0));
      expect(transaction.type, equals(TransactionType.expense));
      expect(transaction.categoryId, equals('cat-1'));
    });

    test('creates income transaction correctly', () {
      final transaction = Transaction(
        id: 'test-id',
        date: now,
        amount: 1000.0,
        type: TransactionType.income,
        categoryId: 'cat-2',
        accountId: 'acc-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(transaction.type, equals(TransactionType.income));
    });

    test('creates transfer transaction with toAccountId', () {
      final transaction = Transaction(
        id: 'test-id',
        date: now,
        amount: 200.0,
        type: TransactionType.transfer,
        categoryId: '',
        accountId: 'acc-1',
        toAccountId: 'acc-2',
        createdAt: now,
        updatedAt: now,
      );

      expect(transaction.type, equals(TransactionType.transfer));
      expect(transaction.toAccountId, equals('acc-2'));
    });

    test('copyWith creates new instance with updated values', () {
      final original = Transaction(
        id: 'test-id',
        date: now,
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(amount: 75.0);

      expect(updated.amount, equals(75.0));
      expect(updated.id, equals(original.id));
      expect(original.amount, equals(50.0)); // Original unchanged
    });

    test('copyWithDelete sets deletedAt', () {
      final transaction = Transaction(
        id: 'test-id',
        date: now,
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        createdAt: now,
        updatedAt: now,
      );

      final deleted = transaction.copyWithDelete();

      expect(deleted.deletedAt, isNotNull);
    });

    test('toJson and fromJson roundtrip', () {
      final transaction = Transaction(
        id: 'test-id',
        date: now,
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        note: 'Test note',
        createdAt: now,
        updatedAt: now,
      );

      final json = transaction.toJson();
      final restored = Transaction.fromJson(json);

      expect(restored.id, equals(transaction.id));
      expect(restored.amount, equals(transaction.amount));
      expect(restored.note, equals(transaction.note));
    });
  });

  group('TransactionType', () {
    test('has correct values', () {
      expect(TransactionType.values.length, equals(3));
      expect(TransactionType.expense.name, equals('expense'));
      expect(TransactionType.income.name, equals('income'));
      expect(TransactionType.transfer.name, equals('transfer'));
    });
  });
}
