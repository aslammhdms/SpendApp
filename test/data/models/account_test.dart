import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/account.dart';

void main() {
  group('Account', () {
    final now = DateTime.now();

    test('creates account correctly', () {
      final account = Account(
        id: 'acc-1',
        name: 'Main Wallet',
        type: AccountType.cash,
        initialBalance: 1000.0,
        currency: 'USD',
        icon: 'wallet',
        color: 0xFF2196F3,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(account.id, equals('acc-1'));
      expect(account.name, equals('Main Wallet'));
      expect(account.type, equals(AccountType.cash));
      expect(account.initialBalance, equals(1000.0));
    });

    test('creates bank account correctly', () {
      final account = Account(
        id: 'acc-2',
        name: 'Checking',
        type: AccountType.bank,
        initialBalance: 5000.0,
        currency: 'USD',
        icon: 'account_balance',
        color: 0xFF4CAF50,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );

      expect(account.type, equals(AccountType.bank));
    });

    test('copyWith creates new instance', () {
      final original = Account(
        id: 'acc-1',
        name: 'Main Wallet',
        type: AccountType.cash,
        initialBalance: 1000.0,
        currency: 'USD',
        icon: 'wallet',
        color: 0xFF2196F3,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'Updated Wallet');

      expect(updated.name, equals('Updated Wallet'));
      expect(original.name, equals('Main Wallet'));
    });

    test('currentBalance can be set explicitly', () {
      final account = Account(
        id: 'acc-1',
        name: 'Main Wallet',
        type: AccountType.cash,
        initialBalance: 1000.0,
        currentBalance: 1500.0,
        currency: 'USD',
        icon: 'wallet',
        color: 0xFF2196F3,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(account.currentBalance, equals(1500.0));
      expect(account.initialBalance, equals(1000.0));
    });

    test('toJson and fromJson roundtrip', () {
      final account = Account(
        id: 'acc-1',
        name: 'Main Wallet',
        type: AccountType.cash,
        initialBalance: 1000.0,
        currency: 'USD',
        icon: 'wallet',
        color: 0xFF2196F3,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final json = account.toJson();
      final restored = Account.fromJson(json);

      expect(restored.id, equals(account.id));
      expect(restored.name, equals(account.name));
      expect(restored.initialBalance, equals(account.initialBalance));
    });
  });

  group('AccountType', () {
    test('has correct values', () {
      expect(AccountType.values.length, equals(7));
      expect(AccountType.cash.name, equals('cash'));
      expect(AccountType.bank.name, equals('bank'));
      expect(AccountType.credit.name, equals('credit'));
      expect(AccountType.savings.name, equals('savings'));
      expect(AccountType.investment.name, equals('investment'));
      expect(AccountType.wallet.name, equals('wallet'));
      expect(AccountType.other.name, equals('other'));
    });
  });
}
