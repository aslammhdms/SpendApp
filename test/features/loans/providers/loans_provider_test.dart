import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/models/person.dart';
import 'package:spendsheet/data/models/loan.dart';
import 'package:spendsheet/data/repositories/person_repository.dart';
import 'package:spendsheet/data/repositories/loan_repository.dart';
import 'package:spendsheet/features/loans/providers/loans_provider.dart';

class MockPersonRepository extends Mock implements PersonRepository {}
class MockLoanRepository extends Mock implements LoanRepository {}

Person _makePerson({String id = 'per_1', String name = 'Alice'}) {
  final now = DateTime.now();
  return Person(id: id, name: name, createdAt: now, updatedAt: now);
}

Loan _makeLoan({
  String id = 'loan_1',
  String personId = 'per_1',
  LoanType type = LoanType.lent,
  double amount = 100,
}) {
  final now = DateTime.now();
  return Loan(
    id: id, personId: personId, type: type, amount: amount,
    date: now, createdAt: now, updatedAt: now,
  );
}

void main() {
  late MockPersonRepository mockPersonRepo;
  late MockLoanRepository mockLoanRepo;
  late LoansNotifier notifier;

  setUpAll(() {
    registerFallbackValue(LoanType.lent);
    registerFallbackValue(DateTime.now());
    registerFallbackValue(_makeLoan());
    registerFallbackValue(_makePerson());
  });

  setUp(() {
    mockPersonRepo = MockPersonRepository();
    mockLoanRepo = MockLoanRepository();

    notifier = LoansNotifier(
      personRepo: mockPersonRepo,
      loanRepo: mockLoanRepo,
    );
  });

  void _stubLoadPeople({
    List<Person> people = const [],
    Map<String, double> balances = const {},
    double owedToYou = 0,
    double youOwe = 0,
  }) {
    when(() => mockPersonRepo.getAll(includeDeleted: any(named: 'includeDeleted')))
        .thenAnswer((_) async => people);
    when(() => mockLoanRepo.getAllBalances())
        .thenAnswer((_) async => balances);
    when(() => mockLoanRepo.getTotalOwedToYou())
        .thenAnswer((_) async => owedToYou);
    when(() => mockLoanRepo.getTotalYouOwe())
        .thenAnswer((_) async => youOwe);
  }

  group('LoansNotifier', () {
    test('initial state is loading', () {
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.people, isEmpty);
    });

    test('loadPeople fetches people with balances', () async {
      _stubLoadPeople(
        people: [_makePerson(id: 'per_1', name: 'Alice')],
        balances: {'per_1': 200.0},
        owedToYou: 200,
      );

      await notifier.loadPeople();

      expect(notifier.state.people.length, 1);
      expect(notifier.state.people.first.netBalance, 200.0);
      expect(notifier.state.totalOwedToYou, 200);
      expect(notifier.state.isLoading, isFalse);
    });

    test('people sorted: unsettled first, then by name', () async {
      _stubLoadPeople(
        people: [
          _makePerson(id: 'per_z', name: 'Zara'),
          _makePerson(id: 'per_a', name: 'Alice'),
          _makePerson(id: 'per_s', name: 'Sam'),
        ],
        balances: {'per_z': 0, 'per_a': 100, 'per_s': -50},
      );

      await notifier.loadPeople();

      final names = notifier.state.people.map((p) => p.name).toList();
      // Alice (100) and Sam (-50) are unsettled, Zara is settled (0)
      // Unsettled first sorted by name: Alice, Sam, then settled: Zara
      expect(names, ['Alice', 'Sam', 'Zara']);
    });

    test('loadPersonLoans fetches loans for specific person', () async {
      final loans = [_makeLoan(id: 'loan_1'), _makeLoan(id: 'loan_2')];
      when(() => mockLoanRepo.getByPersonId(any()))
          .thenAnswer((_) async => loans);

      await notifier.loadPersonLoans('per_1');

      expect(notifier.state.currentPersonLoans.length, 2);
      expect(notifier.state.isLoading, isFalse);
    });

    test('createPerson creates and reloads', () async {
      when(() => mockPersonRepo.create(
            name: any(named: 'name'),
            phone: any(named: 'phone'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => _makePerson());
      _stubLoadPeople(people: [_makePerson()]);

      final person = await notifier.createPerson(name: 'Alice');

      expect(person.name, 'Alice');
      verify(() => mockPersonRepo.create(
            name: 'Alice', phone: null, note: null,
          )).called(1);
    });

    test('createLoan creates and reloads', () async {
      when(() => mockLoanRepo.create(
            personId: any(named: 'personId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            date: any(named: 'date'),
            note: any(named: 'note'),
            isSettlement: any(named: 'isSettlement'),
          )).thenAnswer((_) async => _makeLoan());
      _stubLoadPeople(people: [_makePerson()]);

      await notifier.createLoan(
        personId: 'per_1',
        type: LoanType.lent,
        amount: 100,
        date: DateTime.now(),
      );

      verify(() => mockLoanRepo.create(
            personId: 'per_1',
            type: LoanType.lent,
            amount: 100,
            date: any(named: 'date'),
            note: null,
            isSettlement: false,
          )).called(1);
    });

    test('settleLoan calls repo.settle and reloads', () async {
      when(() => mockLoanRepo.settle(
            personId: any(named: 'personId'),
            amount: any(named: 'amount'),
            date: any(named: 'date'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => _makeLoan());
      _stubLoadPeople();

      await notifier.settleLoan(
        personId: 'per_1', amount: 500, date: DateTime.now(),
      );

      verify(() => mockLoanRepo.settle(
            personId: 'per_1',
            amount: 500,
            date: any(named: 'date'),
            note: null,
          )).called(1);
    });

    test('deletePerson calls repo and reloads', () async {
      when(() => mockPersonRepo.delete(any()))
          .thenAnswer((_) async {});
      _stubLoadPeople();

      await notifier.deletePerson('per_1');

      verify(() => mockPersonRepo.delete('per_1')).called(1);
    });

    test('error during load sets error state', () async {
      when(() => mockPersonRepo.getAll(includeDeleted: any(named: 'includeDeleted')))
          .thenThrow(Exception('Error'));

      await notifier.loadPeople();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
