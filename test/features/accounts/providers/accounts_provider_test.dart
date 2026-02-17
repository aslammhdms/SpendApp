import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/account.dart';
import 'package:spendsheet/data/repositories/account_repository.dart';
import 'package:spendsheet/features/accounts/providers/accounts_provider.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

Account _makeAccount({
  String id = 'acc_1',
  String name = 'Checking',
  double initialBalance = 1000,
  double currentBalance = 1000,
}) {
  final now = DateTime.now();
  return Account(
    id: id, name: name, type: AccountType.bank,
    initialBalance: initialBalance, currency: 'USD',
    icon: '🏦', color: 0xFF2196F3, sortOrder: 0,
    createdAt: now, updatedAt: now,
    currentBalance: currentBalance,
  );
}

void main() {
  late MockAccountRepository mockRepo;
  late AccountsNotifier notifier;

  setUpAll(() {
    registerFallbackValue(AccountType.bank);
    registerFallbackValue(_makeAccount());
  });

  setUp(() {
    mockRepo = MockAccountRepository();
    notifier = AccountsNotifier(mockRepo);
  });

  group('AccountsNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state.accounts, isEmpty);
      expect(notifier.state.totalBalance, 0);
      expect(notifier.state.isLoading, isFalse);
    });

    test('loadAccounts populates accounts and totalBalance', () async {
      final accounts = [
        _makeAccount(id: 'acc_1', currentBalance: 5000),
        _makeAccount(id: 'acc_2', currentBalance: 3000),
      ];
      when(() => mockRepo.getAllWithBalances())
          .thenAnswer((_) async => accounts);
      when(() => mockRepo.getTotalBalance())
          .thenAnswer((_) async => 8000);

      await notifier.loadAccounts();

      expect(notifier.state.accounts.length, 2);
      expect(notifier.state.totalBalance, 8000);
      expect(notifier.state.isLoading, isFalse);
    });

    test('createAccount calls repo and reloads', () async {
      when(() => mockRepo.create(
            name: any(named: 'name'),
            type: any(named: 'type'),
            initialBalance: any(named: 'initialBalance'),
            currency: any(named: 'currency'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
          )).thenAnswer((_) async => _makeAccount());
      when(() => mockRepo.getAllWithBalances())
          .thenAnswer((_) async => [_makeAccount()]);
      when(() => mockRepo.getTotalBalance())
          .thenAnswer((_) async => 1000);

      await notifier.createAccount(
        name: 'Test', type: AccountType.bank,
        initialBalance: 1000, currency: 'USD',
        icon: '🏦', color: 0xFF2196F3,
      );

      verify(() => mockRepo.create(
            name: 'Test', type: AccountType.bank,
            initialBalance: 1000, currency: 'USD',
            icon: '🏦', color: 0xFF2196F3,
          )).called(1);
    });

    test('deleteAccount removes optimistically', () async {
      final accounts = [
        _makeAccount(id: 'acc_1'),
        _makeAccount(id: 'acc_2', name: 'Savings'),
      ];
      when(() => mockRepo.getAllWithBalances())
          .thenAnswer((_) async => accounts);
      when(() => mockRepo.getTotalBalance())
          .thenAnswer((_) async => 2000);
      when(() => mockRepo.delete(any()))
          .thenAnswer((_) async {});

      await notifier.loadAccounts();
      await notifier.deleteAccount('acc_1');

      expect(notifier.state.accounts.length, 1);
      expect(notifier.state.accounts.first.id, 'acc_2');
    });

    test('error during load sets error state', () async {
      when(() => mockRepo.getAllWithBalances())
          .thenThrow(Exception('Error'));

      await notifier.loadAccounts();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
    });

    test('updateAccount calls repo and reloads', () async {
      final account = _makeAccount();
      when(() => mockRepo.update(any()))
          .thenAnswer((_) async => account);
      when(() => mockRepo.getAllWithBalances())
          .thenAnswer((_) async => [account]);
      when(() => mockRepo.getTotalBalance())
          .thenAnswer((_) async => 1000);

      await notifier.updateAccount(account);

      verify(() => mockRepo.update(account)).called(1);
    });
  });
}
