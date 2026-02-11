import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/person.dart';
import '../../../data/models/loan.dart';
import '../../../data/local/local_person_dao.dart';
import '../../../data/repositories/person_repository.dart';
import '../../../data/repositories/loan_repository.dart';
import '../../home/providers/dashboard_provider.dart';

// DAO providers
final localPersonDaoProvider = Provider((ref) => LocalPersonDao());

// Repository providers
final personRepositoryProvider = Provider((ref) => PersonRepository(
      localDao: ref.watch(localPersonDaoProvider),
      syncQueueDao: ref.watch(syncQueueDaoProvider),
      syncEngine: ref.watch(syncEngineProvider),
    ));

// State
class LoansState {
  final List<Person> people;
  final List<Loan> currentPersonLoans;
  final double totalOwedToYou;
  final double totalYouOwe;
  final bool isLoading;
  final String? error;

  const LoansState({
    this.people = const [],
    this.currentPersonLoans = const [],
    this.totalOwedToYou = 0,
    this.totalYouOwe = 0,
    this.isLoading = true,
    this.error,
  });

  LoansState copyWith({
    List<Person>? people,
    List<Loan>? currentPersonLoans,
    double? totalOwedToYou,
    double? totalYouOwe,
    bool? isLoading,
    String? error,
  }) {
    return LoansState(
      people: people ?? this.people,
      currentPersonLoans: currentPersonLoans ?? this.currentPersonLoans,
      totalOwedToYou: totalOwedToYou ?? this.totalOwedToYou,
      totalYouOwe: totalYouOwe ?? this.totalYouOwe,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class LoansNotifier extends StateNotifier<LoansState> {
  final PersonRepository _personRepo;
  final LoanRepository _loanRepo;

  LoansNotifier({
    required PersonRepository personRepo,
    required LoanRepository loanRepo,
  })  : _personRepo = personRepo,
        _loanRepo = loanRepo,
        super(const LoansState());

  Future<void> loadPeople() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final people = await _personRepo.getAll();
      final balances = await _loanRepo.getAllBalances();
      final totalOwed = await _loanRepo.getTotalOwedToYou();
      final totalYouOwe = await _loanRepo.getTotalYouOwe();

      // Populate netBalance on each person
      final peopleWithBalances = people.map((p) {
        return p.copyWith(netBalance: balances[p.id] ?? 0);
      }).toList();

      // Sort: unsettled (non-zero balance) first, then by name
      peopleWithBalances.sort((a, b) {
        final aSettled = a.netBalance == 0;
        final bSettled = b.netBalance == 0;
        if (aSettled != bSettled) return aSettled ? 1 : -1;
        return a.name.compareTo(b.name);
      });

      state = state.copyWith(
        people: peopleWithBalances,
        totalOwedToYou: totalOwed,
        totalYouOwe: totalYouOwe,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load loans: $e',
      );
    }
  }

  Future<void> loadPersonLoans(String personId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final loans = await _loanRepo.getByPersonId(personId);
      state = state.copyWith(
        currentPersonLoans: loans,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load loans: $e',
      );
    }
  }

  Future<Person> createPerson({
    required String name,
    String? phone,
    String? note,
  }) async {
    final person = await _personRepo.create(
      name: name,
      phone: phone,
      note: note,
    );
    await loadPeople();
    return person;
  }

  Future<Loan> createLoan({
    required String personId,
    required LoanType type,
    required double amount,
    required DateTime date,
    String? note,
    bool isSettlement = false,
  }) async {
    final loan = await _loanRepo.create(
      personId: personId,
      type: type,
      amount: amount,
      date: date,
      note: note,
      isSettlement: isSettlement,
    );
    await loadPeople();
    return loan;
  }

  Future<Loan> settleLoan({
    required String personId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final loan = await _loanRepo.settle(
      personId: personId,
      amount: amount,
      date: date,
      note: note,
    );
    await loadPeople();
    return loan;
  }

  Future<void> deleteLoan(String id) async {
    await _loanRepo.delete(id);
    await loadPeople();
  }

  Future<void> deletePerson(String id) async {
    await _personRepo.delete(id);
    await loadPeople();
  }
}

// Provider
final loansProvider =
    StateNotifierProvider<LoansNotifier, LoansState>((ref) {
  return LoansNotifier(
    personRepo: ref.watch(personRepositoryProvider),
    loanRepo: ref.watch(loanRepositoryProvider),
  );
});
