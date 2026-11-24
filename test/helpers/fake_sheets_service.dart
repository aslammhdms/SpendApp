import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/core/constants/sheet_constants.dart';
import 'package:spendsheet/core/errors/app_exceptions.dart';
import 'package:spendsheet/data/models/account.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/data/models/goal.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';
import 'package:spendsheet/data/models/loan.dart';
import 'package:spendsheet/data/models/person.dart';
import 'package:spendsheet/data/models/transaction.dart';
import 'package:spendsheet/data/remote/sheets_service.dart';

/// One tab of the fake spreadsheet. Row 1 holds the headers, so the first
/// data row is row 2, as in Google Sheets.
class FakeTab<T> {
  final String Function(T) idOf;
  final List<T> rows = [];

  FakeTab(this.idOf);

  int rowOf(String id) {
    final index = rows.indexWhere((row) => idOf(row) == id);
    return index < 0 ? -1 : index + 2;
  }

  /// How many rows carry [id]; more than one means a duplicate append.
  int countOf(String id) => rows.where((row) => idOf(row) == id).length;

  T? byId(String id) {
    for (final row in rows) {
      if (idOf(row) == id) return row;
    }
    return null;
  }
}

/// In-memory stand-in for the user's spreadsheet.
class FakeSheetsService extends Fake implements SheetsService {
  final transactions = FakeTab<Transaction>((t) => t.id);
  final categories = FakeTab<Category>((c) => c.id);
  final accounts = FakeTab<Account>((a) => a.id);
  final budgets = FakeTab<Budget>((b) => b.id);
  final people = FakeTab<Person>((p) => p.id);
  final loans = FakeTab<Loan>((l) => l.id);
  final recurring = FakeTab<RecurringRule>((r) => r.id);
  final goals = FakeTab<Goal>((g) => g.id);

  /// Writes for these IDs fail, as if the sheet rejected them.
  final Set<String> failingIds = {};

  /// Row lookups fail, as if the network dropped mid-push.
  bool failLookups = false;

  /// While set, appends wait for it to complete, so a test can act while a
  /// push is still in flight.
  Completer<void>? appendGate;

  /// Runs at the start of every append, before the row is written.
  Future<void> Function()? onAppend;

  FakeTab<dynamic> _tab(String sheetName) => switch (sheetName) {
        SheetConstants.transactionsSheet => transactions,
        SheetConstants.categoriesSheet => categories,
        SheetConstants.accountsSheet => accounts,
        SheetConstants.budgetsSheet => budgets,
        SheetConstants.peopleSheet => people,
        SheetConstants.loansSheet => loans,
        SheetConstants.recurringSheet => recurring,
        SheetConstants.goalsSheet => goals,
        _ => throw ArgumentError('Unknown sheet $sheetName'),
      };

  void _checkWrite(String id) {
    if (failingIds.contains(id)) {
      throw SheetsException.writeFailed('sheet rejected $id');
    }
  }

  Future<void> _append<T>(FakeTab<T> tab, T row) async {
    await onAppend?.call();
    if (appendGate != null) await appendGate!.future;
    _checkWrite(tab.idOf(row));
    tab.rows.add(row);
  }

  Future<void> _update<T>(FakeTab<T> tab, T row, int rowIndex) async {
    _checkWrite(tab.idOf(row));
    tab.rows[rowIndex - 2] = row;
  }

  @override
  Future<void> ensureSheetsExist(String spreadsheetId) async {}

  @override
  Future<int> findRowByIdInSheet(
    String spreadsheetId,
    String sheetName,
    String id,
  ) async {
    if (failLookups) throw SheetsException.readFailed('network down');
    return _tab(sheetName).rowOf(id);
  }

  @override
  Future<List<Transaction>> getAllTransactions(String spreadsheetId) async =>
      List.of(transactions.rows);

  @override
  Future<List<Category>> getAllCategories(String spreadsheetId) async =>
      List.of(categories.rows);

  @override
  Future<List<Account>> getAllAccounts(String spreadsheetId) async =>
      List.of(accounts.rows);

  @override
  Future<List<Budget>> getAllBudgets(String spreadsheetId) async =>
      List.of(budgets.rows);

  @override
  Future<List<Person>> getAllPeople(String spreadsheetId) async =>
      List.of(people.rows);

  @override
  Future<List<Loan>> getAllLoans(String spreadsheetId) async =>
      List.of(loans.rows);

  @override
  Future<void> appendTransaction(String spreadsheetId, Transaction t) =>
      _append(transactions, t);

  @override
  Future<void> updateTransaction(
          String spreadsheetId, Transaction t, int rowIndex) =>
      _update(transactions, t, rowIndex);

  @override
  Future<void> appendCategory(String spreadsheetId, Category c) =>
      _append(categories, c);

  @override
  Future<void> updateCategory(String spreadsheetId, Category c, int rowIndex) =>
      _update(categories, c, rowIndex);

  @override
  Future<void> appendAccount(String spreadsheetId, Account a) =>
      _append(accounts, a);

  @override
  Future<void> updateAccount(String spreadsheetId, Account a, int rowIndex) =>
      _update(accounts, a, rowIndex);

  @override
  Future<void> appendBudget(String spreadsheetId, Budget b) =>
      _append(budgets, b);

  @override
  Future<void> updateBudget(String spreadsheetId, Budget b, int rowIndex) =>
      _update(budgets, b, rowIndex);

  @override
  Future<void> appendPerson(String spreadsheetId, Person p) =>
      _append(people, p);

  @override
  Future<void> updatePerson(String spreadsheetId, Person p, int rowIndex) =>
      _update(people, p, rowIndex);

  @override
  Future<void> appendLoan(String spreadsheetId, Loan l) => _append(loans, l);

  @override
  Future<void> updateLoan(String spreadsheetId, Loan l, int rowIndex) =>
      _update(loans, l, rowIndex);

  @override
  Future<List<RecurringRule>> getAllRecurringRules(String spreadsheetId) async =>
      List.of(recurring.rows);

  @override
  Future<void> appendRecurringRule(String spreadsheetId, RecurringRule r) =>
      _append(recurring, r);

  @override
  Future<void> updateRecurringRule(
          String spreadsheetId, RecurringRule r, int rowIndex) =>
      _update(recurring, r, rowIndex);

  @override
  Future<List<Goal>> getAllGoals(String spreadsheetId) async =>
      List.of(goals.rows);

  @override
  Future<void> appendGoal(String spreadsheetId, Goal g) => _append(goals, g);

  @override
  Future<void> updateGoal(String spreadsheetId, Goal g, int rowIndex) =>
      _update(goals, g, rowIndex);
}
