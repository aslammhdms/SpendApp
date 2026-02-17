import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';
import 'package:spendsheet/data/repositories/account_repository.dart';
import 'package:spendsheet/data/repositories/budget_repository.dart';
import 'package:spendsheet/data/repositories/category_repository.dart';
import 'package:spendsheet/data/repositories/loan_repository.dart';
import 'package:spendsheet/data/repositories/person_repository.dart';
import 'package:spendsheet/data/repositories/settings_repository.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockLoanRepository extends Mock implements LoanRepository {}

class MockPersonRepository extends Mock implements PersonRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}
