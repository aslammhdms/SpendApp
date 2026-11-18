import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/models/loan.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';
import 'package:spendsheet/data/repositories/loan_repository.dart';
import 'package:spendsheet/data/repositories/person_repository.dart';
import 'package:spendsheet/features/transactions/providers/transactions_provider.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockLoanRepository extends Mock implements LoanRepository {}
class MockPersonRepository extends Mock implements PersonRepository {}

Transaction _makeTransaction({
  required String id,
  double amount = 50,
  TransactionType type = TransactionType.expense,
  String? note,
}) {
  final now = DateTime.now();
  return Transaction(
    id: id, date: now, amount: amount, type: type,
    categoryId: 'cat_food', accountId: 'acc_cash', note: note,
    createdAt: now, updatedAt: now,
  );
}

void main() {
  late MockTransactionRepository mockTxnRepo;
  late MockLoanRepository mockLoanRepo;
  late MockPersonRepository mockPersonRepo;
  late TransactionsNotifier notifier;

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(DateTime.now());
    registerFallbackValue(_makeTransaction(id: 'fallback'));
  });

  setUp(() {
    mockTxnRepo = MockTransactionRepository();
    mockLoanRepo = MockLoanRepository();
    mockPersonRepo = MockPersonRepository();

    notifier = TransactionsNotifier(
      mockTxnRepo,
      loanRepo: mockLoanRepo,
      personRepo: mockPersonRepo,
    );

    // Default stubs
    when(() => mockLoanRepo.getAll(includeDeleted: any(named: 'includeDeleted')))
        .thenAnswer((_) async => []);
    when(() => mockPersonRepo.getAll(includeDeleted: any(named: 'includeDeleted')))
        .thenAnswer((_) async => []);
  });

  group('TransactionsNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state.transactions, isEmpty);
      expect(notifier.state.loans, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.hasMore, isTrue);
    });

    test('loadTransactions fetches paginated list', () async {
      final txns = List.generate(3, (i) => _makeTransaction(id: 'txn_$i'));
      when(() => mockTxnRepo.getPaginated(any(), any()))
          .thenAnswer((_) async => txns);

      await notifier.loadTransactions(refresh: true);

      expect(notifier.state.transactions.length, 3);
      expect(notifier.state.isLoading, isFalse);
    });

    test('loadTransactions sets hasMore false when < pageSize', () async {
      final txns = List.generate(10, (i) => _makeTransaction(id: 'txn_$i'));
      when(() => mockTxnRepo.getPaginated(any(), any()))
          .thenAnswer((_) async => txns);

      await notifier.loadTransactions(refresh: true);

      expect(notifier.state.hasMore, isFalse); // 10 < 50
    });

    test('deleteTransaction removes from list and calls repo', () async {
      final txns = [
        _makeTransaction(id: 'txn_1'),
        _makeTransaction(id: 'txn_2'),
      ];
      when(() => mockTxnRepo.getPaginated(any(), any()))
          .thenAnswer((_) async => txns);
      when(() => mockTxnRepo.delete(any()))
          .thenAnswer((_) async {});

      await notifier.loadTransactions(refresh: true);
      await notifier.deleteTransaction('txn_1');

      expect(notifier.state.transactions.length, 1);
      expect(notifier.state.transactions.first.id, 'txn_2');
      verify(() => mockTxnRepo.delete('txn_1')).called(1);
    });

    test('deleteLoan removes from loan list', () async {
      final loans = [
        Loan(
          id: 'loan_1', personId: 'per_1', type: LoanType.lent,
          amount: 100, date: DateTime.now(),
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
      ];
      when(() => mockTxnRepo.getPaginated(any(), any()))
          .thenAnswer((_) async => []);
      when(() => mockLoanRepo.getAll(includeDeleted: any(named: 'includeDeleted')))
          .thenAnswer((_) async => loans);
      when(() => mockLoanRepo.delete(any()))
          .thenAnswer((_) async {});

      await notifier.loadTransactions(refresh: true);
      await notifier.deleteLoan('loan_1');

      expect(notifier.state.loans, isEmpty);
      verify(() => mockLoanRepo.delete('loan_1')).called(1);
    });

    test('setFilter reloads with filter applied', () async {
      when(() => mockTxnRepo.getByType(any()))
          .thenAnswer((_) async => [_makeTransaction(id: 'txn_exp')]);

      notifier.setFilter(
          const TransactionFilter(type: TransactionType.expense));

      // Let the async loadTransactions complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.filter.type, TransactionType.expense);
    });

    test('clearFilter resets and reloads', () async {
      when(() => mockTxnRepo.getPaginated(any(), any()))
          .thenAnswer((_) async => []);

      notifier.clearFilter();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.filter.hasFilters, isFalse);
    });

    test('error during load sets error state', () async {
      when(() => mockTxnRepo.getPaginated(any(), any()))
          .thenThrow(Exception('DB error'));

      await notifier.loadTransactions(refresh: true);

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('TransactionFilter', () {
    test('hasFilters returns false when empty', () {
      const filter = TransactionFilter();
      expect(filter.hasFilters, isFalse);
    });

    test('hasFilters returns true with type set', () {
      const filter = TransactionFilter(type: TransactionType.expense);
      expect(filter.hasFilters, isTrue);
    });

    test('clearField removes specific field', () {
      const filter = TransactionFilter(
        type: TransactionType.expense,
        categoryId: 'cat_food',
      );
      final cleared = filter.clearField('type');
      expect(cleared.type, isNull);
      expect(cleared.categoryId, 'cat_food');
    });

    test('clear resets everything', () {
      const filter = TransactionFilter(
        type: TransactionType.expense,
        searchQuery: 'test',
      );
      final cleared = filter.clear();
      expect(cleared.hasFilters, isFalse);
    });
  });

  group('TransactionsState', () {
    test('groupedByDate groups transactions by date', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final state = TransactionsState(
        transactions: [
          _makeTransaction(id: 'txn_today'),
          Transaction(
            id: 'txn_yesterday', date: yesterday, amount: 20,
            type: TransactionType.expense, categoryId: 'cat_food',
            accountId: 'acc_cash', createdAt: yesterday, updatedAt: yesterday,
          ),
        ],
      );

      final grouped = state.groupedByDate;
      expect(grouped.containsKey('Today'), isTrue);
      expect(grouped.containsKey('Yesterday'), isTrue);
    });

    test('isEmpty returns true when both lists empty', () {
      const state = TransactionsState();
      expect(state.isEmpty, isTrue);
    });
  });
}
