import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/loan.dart';

void main() {
  group('Loan', () {
    final now = DateTime.now();

    test('creates loan correctly', () {
      final loan = Loan(
        id: 'l-1',
        personId: 'p-1',
        type: LoanType.lent,
        amount: 50.0,
        note: 'Dinner',
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(loan.id, equals('l-1'));
      expect(loan.personId, equals('p-1'));
      expect(loan.type, equals(LoanType.lent));
      expect(loan.amount, equals(50.0));
      expect(loan.note, equals('Dinner'));
      expect(loan.isSettlement, isFalse);
      expect(loan.isDeleted, isFalse);
    });

    test('isLent returns true for lent type', () {
      final loan = Loan(
        id: 'l-1',
        personId: 'p-1',
        type: LoanType.lent,
        amount: 50.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(loan.isLent, isTrue);
      expect(loan.isBorrowed, isFalse);
    });

    test('isBorrowed returns true for borrowed type', () {
      final loan = Loan(
        id: 'l-2',
        personId: 'p-1',
        type: LoanType.borrowed,
        amount: 30.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(loan.isBorrowed, isTrue);
      expect(loan.isLent, isFalse);
    });

    test('isSettlement flag works', () {
      final loan = Loan(
        id: 'l-3',
        personId: 'p-1',
        type: LoanType.borrowed,
        amount: 50.0,
        date: now,
        isSettlement: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(loan.isSettlement, isTrue);
    });

    test('copyWithDelete sets deletedAt', () {
      final loan = Loan(
        id: 'l-1',
        personId: 'p-1',
        type: LoanType.lent,
        amount: 50.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      final deleted = loan.copyWithDelete();

      expect(deleted.isDeleted, isTrue);
      expect(deleted.deletedAt, isNotNull);
      expect(loan.isDeleted, isFalse);
    });

    test('toJson and fromJson roundtrip', () {
      final loan = Loan(
        id: 'l-1',
        personId: 'p-1',
        type: LoanType.lent,
        amount: 50.0,
        note: 'Test',
        date: now,
        isSettlement: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = loan.toJson();
      final restored = Loan.fromJson(json);

      expect(restored.id, equals(loan.id));
      expect(restored.personId, equals(loan.personId));
      expect(restored.type, equals(loan.type));
      expect(restored.amount, equals(loan.amount));
      expect(restored.isSettlement, equals(loan.isSettlement));
    });
  });

  group('LoanType', () {
    test('has correct values', () {
      expect(LoanType.values.length, equals(2));
      expect(LoanType.lent.name, equals('lent'));
      expect(LoanType.borrowed.name, equals('borrowed'));
    });
  });
}
