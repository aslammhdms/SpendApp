import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:flutter/foundation.dart' hide Category;
import '../../core/constants/sheet_constants.dart';
import '../../core/constants/category_defaults.dart';
import '../../core/utils/id_generator.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/recurring_rule.dart';
import '../models/person.dart';
import '../models/loan.dart';
import 'google_auth_service.dart';

class SheetsService {
  final GoogleAuthService _authService;
  sheets.SheetsApi? _sheetsApi;

  SheetsService(this._authService);

  Future<sheets.SheetsApi> get _api async {
    // Always get a fresh auth client to avoid stale token issues
    final client = await _authService.getAuthClient();
    _sheetsApi = sheets.SheetsApi(client);
    return _sheetsApi!;
  }

  Future<String> createSpendSheet() async {
    try {
      final api = await _api;

      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: SheetConstants.spreadsheetTitle,
        ),
        sheets: [
          _createSheet(SheetConstants.transactionsSheet, 0),
          _createSheet(SheetConstants.categoriesSheet, 1),
          _createSheet(SheetConstants.accountsSheet, 2),
          _createSheet(SheetConstants.budgetsSheet, 3),
          _createSheet(SheetConstants.recurringSheet, 4),
          _createSheet(SheetConstants.settingsSheet, 5),
          _createSheet(SheetConstants.metaSheet, 6),
          _createSheet(SheetConstants.peopleSheet, 7),
          _createSheet(SheetConstants.loansSheet, 8),
        ],
      );

      final created = await api.spreadsheets.create(spreadsheet);
      final spreadsheetId = created.spreadsheetId!;

      // Set up headers and default data
      await _setupHeaders(spreadsheetId);
      await _setupDefaultCategories(spreadsheetId);
      await _setupDefaultAccounts(spreadsheetId);
      await _setupMetaData(spreadsheetId);

      return spreadsheetId;
    } catch (e) {
      throw SheetsException.createFailed(e);
    }
  }

  sheets.Sheet _createSheet(String title, int index) {
    return sheets.Sheet(
      properties: sheets.SheetProperties(
        title: title,
        index: index,
        gridProperties: sheets.GridProperties(
          frozenRowCount: 1,
        ),
      ),
    );
  }

  Future<void> _setupHeaders(String spreadsheetId) async {
    final api = await _api;

    final requests = <sheets.Request>[
      _createHeaderRequest(SheetConstants.transactionsSheet, SheetConstants.transactionHeaders),
      _createHeaderRequest(SheetConstants.categoriesSheet, SheetConstants.categoryHeaders),
      _createHeaderRequest(SheetConstants.accountsSheet, SheetConstants.accountHeaders),
      _createHeaderRequest(SheetConstants.budgetsSheet, SheetConstants.budgetHeaders),
      _createHeaderRequest(SheetConstants.recurringSheet, SheetConstants.recurringHeaders),
      _createHeaderRequest(SheetConstants.settingsSheet, SheetConstants.settingsHeaders),
      _createHeaderRequest(SheetConstants.metaSheet, SheetConstants.metaHeaders),
      _createHeaderRequest(SheetConstants.peopleSheet, SheetConstants.personHeaders),
      _createHeaderRequest(SheetConstants.loansSheet, SheetConstants.loanHeaders),
    ];

    // Use batchUpdate for efficiency
    final valueRanges = <sheets.ValueRange>[
      sheets.ValueRange(
        range: '${SheetConstants.transactionsSheet}!A1',
        values: [SheetConstants.transactionHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.categoriesSheet}!A1',
        values: [SheetConstants.categoryHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.accountsSheet}!A1',
        values: [SheetConstants.accountHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.budgetsSheet}!A1',
        values: [SheetConstants.budgetHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.recurringSheet}!A1',
        values: [SheetConstants.recurringHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.settingsSheet}!A1',
        values: [SheetConstants.settingsHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.metaSheet}!A1',
        values: [SheetConstants.metaHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.peopleSheet}!A1',
        values: [SheetConstants.personHeaders],
      ),
      sheets.ValueRange(
        range: '${SheetConstants.loansSheet}!A1',
        values: [SheetConstants.loanHeaders],
      ),
    ];

    await api.spreadsheets.values.batchUpdate(
      sheets.BatchUpdateValuesRequest(
        valueInputOption: 'RAW',
        data: valueRanges,
      ),
      spreadsheetId,
    );
  }

  sheets.Request _createHeaderRequest(String sheetTitle, List<String> headers) {
    return sheets.Request();
  }

  Future<void> _setupDefaultCategories(String spreadsheetId) async {
    final api = await _api;
    final now = DateTime.now();
    final categories = <List<dynamic>>[];

    // Expense categories
    int sortOrder = 0;
    for (final cat in CategoryDefaults.expenseCategories) {
      categories.add([
        IdGenerator.generate(),
        cat.name,
        'expense',
        cat.icon,
        cat.color,
        sortOrder++,
        now.toIso8601String(),
        now.toIso8601String(),
        '',
      ]);
    }

    // Income categories
    sortOrder = 0;
    for (final cat in CategoryDefaults.incomeCategories) {
      categories.add([
        IdGenerator.generate(),
        cat.name,
        'income',
        cat.icon,
        cat.color,
        sortOrder++,
        now.toIso8601String(),
        now.toIso8601String(),
        '',
      ]);
    }

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: categories),
      spreadsheetId,
      '${SheetConstants.categoriesSheet}!A2',
      valueInputOption: 'RAW',
    );
  }

  Future<void> _setupDefaultAccounts(String spreadsheetId) async {
    final api = await _api;
    final now = DateTime.now();
    final accounts = <List<dynamic>>[];

    int sortOrder = 0;
    for (final acc in CategoryDefaults.defaultAccounts) {
      accounts.add([
        IdGenerator.generate(),
        acc.name,
        acc.type,
        0.0, // initial balance
        'USD',
        acc.icon,
        acc.color,
        sortOrder++,
        now.toIso8601String(),
        now.toIso8601String(),
        '',
      ]);
    }

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: accounts),
      spreadsheetId,
      '${SheetConstants.accountsSheet}!A2',
      valueInputOption: 'RAW',
    );
  }

  Future<void> _setupMetaData(String spreadsheetId) async {
    final api = await _api;

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [
        ['app_identifier', SheetConstants.appIdentifier],
        ['version', '1'],
        ['created_at', DateTime.now().toIso8601String()],
      ]),
      spreadsheetId,
      '${SheetConstants.metaSheet}!A2',
      valueInputOption: 'RAW',
    );
  }

  Future<bool> validateSpreadsheet(String spreadsheetId) async {
    try {
      final api = await _api;

      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        '${SheetConstants.metaSheet}!A:B',
      );

      final values = response.values;
      if (values == null || values.isEmpty) return false;

      for (final row in values) {
        if (row.length >= 2 &&
            row[0] == 'app_identifier' &&
            row[1] == SheetConstants.appIdentifier) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Transaction Operations
  Future<List<Transaction>> getAllTransactions(String spreadsheetId) async {
    try {
      final api = await _api;
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        SheetConstants.getDataRange(SheetConstants.transactionsSheet),
      );

      final values = response.values;
      if (values == null || values.isEmpty) return [];

      return values.map((row) => Transaction.fromSheetRow(row)).toList();
    } catch (e) {
      throw SheetsException.readFailed(e);
    }
  }

  Future<void> appendTransaction(String spreadsheetId, Transaction transaction) async {
    try {
      final api = await _api;
      final row = transaction.toSheetRow();
      final values = [
        [
          row['id'],
          row['date'],
          row['amount'],
          row['type'],
          row['category_id'],
          row['account_id'],
          row['to_account_id'],
          row['note'],
          row['receipt_url'],
          row['recurring_id'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.transactionsSheet}!A2',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  Future<void> updateTransaction(
    String spreadsheetId,
    Transaction transaction,
    int rowIndex,
  ) async {
    try {
      final api = await _api;
      final row = transaction.toSheetRow();
      final values = [
        [
          row['id'],
          row['date'],
          row['amount'],
          row['type'],
          row['category_id'],
          row['account_id'],
          row['to_account_id'],
          row['note'],
          row['receipt_url'],
          row['recurring_id'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.update(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.transactionsSheet}!A$rowIndex',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  // Category Operations
  Future<List<Category>> getAllCategories(String spreadsheetId) async {
    try {
      final api = await _api;
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        SheetConstants.getDataRange(SheetConstants.categoriesSheet),
      );

      final values = response.values;
      if (values == null || values.isEmpty) return [];

      return values.map<Category>((row) => Category.fromSheetRow(row)).toList();
    } catch (e) {
      throw SheetsException.readFailed(e);
    }
  }

  Future<void> appendCategory(String spreadsheetId, Category category) async {
    try {
      final api = await _api;
      final row = category.toSheetRow();
      final values = [
        [
          row['id'],
          row['name'],
          row['type'],
          row['icon'],
          row['color'],
          row['sort_order'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.categoriesSheet}!A2',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  // Account Operations
  Future<List<Account>> getAllAccounts(String spreadsheetId) async {
    try {
      final api = await _api;
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        SheetConstants.getDataRange(SheetConstants.accountsSheet),
      );

      final values = response.values;
      if (values == null || values.isEmpty) return [];

      return values.map((row) => Account.fromSheetRow(row)).toList();
    } catch (e) {
      throw SheetsException.readFailed(e);
    }
  }

  Future<void> appendAccount(String spreadsheetId, Account account) async {
    try {
      final api = await _api;
      final row = account.toSheetRow();
      final values = [
        [
          row['id'],
          row['name'],
          row['type'],
          row['initial_balance'],
          row['currency'],
          row['icon'],
          row['color'],
          row['sort_order'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.accountsSheet}!A2',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  // Budget Operations
  Future<List<Budget>> getAllBudgets(String spreadsheetId) async {
    try {
      final api = await _api;
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        SheetConstants.getDataRange(SheetConstants.budgetsSheet),
      );

      final values = response.values;
      if (values == null || values.isEmpty) return [];

      return values.map((row) => Budget.fromSheetRow(row)).toList();
    } catch (e) {
      throw SheetsException.readFailed(e);
    }
  }

  Future<void> appendBudget(String spreadsheetId, Budget budget) async {
    try {
      final api = await _api;
      final row = budget.toSheetRow();
      final values = [
        [
          row['id'],
          row['name'],
          row['amount'],
          row['period'],
          row['category_id'],
          row['start_date'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.budgetsSheet}!A2',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  // Recurring Rules Operations
  Future<List<RecurringRule>> getAllRecurringRules(String spreadsheetId) async {
    try {
      final api = await _api;
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        SheetConstants.getDataRange(SheetConstants.recurringSheet),
      );

      final values = response.values;
      if (values == null || values.isEmpty) return [];

      return values.map((row) => RecurringRule.fromSheetRow(row)).toList();
    } catch (e) {
      throw SheetsException.readFailed(e);
    }
  }

  // Batch Operations
  Future<void> batchUpdate(
    String spreadsheetId,
    List<sheets.ValueRange> updates,
  ) async {
    try {
      final api = await _api;
      await api.spreadsheets.values.batchUpdate(
        sheets.BatchUpdateValuesRequest(
          valueInputOption: 'RAW',
          data: updates,
        ),
        spreadsheetId,
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  Future<int> findRowByIdInSheet(
    String spreadsheetId,
    String sheetName,
    String id,
  ) async {
    try {
      final api = await _api;
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        '$sheetName!A:A',
      );

      final values = response.values;
      if (values == null) return -1;

      for (int i = 0; i < values.length; i++) {
        if (values[i].isNotEmpty && values[i][0] == id) {
          return i + 1; // 1-indexed row number
        }
      }
      return -1;
    } catch (e) {
      return -1;
    }
  }

  // Generic row update for any sheet
  Future<void> updateRow(
    String spreadsheetId,
    String sheetName,
    List<dynamic> rowValues,
    int rowIndex,
  ) async {
    try {
      final api = await _api;
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: [rowValues]),
        spreadsheetId,
        '$sheetName!A$rowIndex',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  // Category update
  Future<void> updateCategory(
    String spreadsheetId,
    Category category,
    int rowIndex,
  ) async {
    final row = category.toSheetRow();
    await updateRow(spreadsheetId, SheetConstants.categoriesSheet, [
      row['id'],
      row['name'],
      row['type'],
      row['icon'],
      row['color'],
      row['sort_order'],
      row['created_at'],
      row['updated_at'],
      row['deleted_at'],
    ], rowIndex);
  }

  // Account update
  Future<void> updateAccount(
    String spreadsheetId,
    Account account,
    int rowIndex,
  ) async {
    final row = account.toSheetRow();
    await updateRow(spreadsheetId, SheetConstants.accountsSheet, [
      row['id'],
      row['name'],
      row['type'],
      row['initial_balance'],
      row['currency'],
      row['icon'],
      row['color'],
      row['sort_order'],
      row['created_at'],
      row['updated_at'],
      row['deleted_at'],
    ], rowIndex);
  }

  // Budget update
  Future<void> updateBudget(
    String spreadsheetId,
    Budget budget,
    int rowIndex,
  ) async {
    final row = budget.toSheetRow();
    await updateRow(spreadsheetId, SheetConstants.budgetsSheet, [
      row['id'],
      row['name'],
      row['amount'],
      row['period'],
      row['category_id'],
      row['start_date'],
      row['created_at'],
      row['updated_at'],
      row['deleted_at'],
    ], rowIndex);
  }

  // Person Operations
  Future<void> appendPerson(String spreadsheetId, Person person) async {
    try {
      final api = await _api;
      final row = person.toSheetRow();
      final values = [
        [
          row['id'],
          row['name'],
          row['phone'],
          row['note'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.peopleSheet}!A2',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  Future<void> updatePerson(
    String spreadsheetId,
    Person person,
    int rowIndex,
  ) async {
    final row = person.toSheetRow();
    await updateRow(spreadsheetId, SheetConstants.peopleSheet, [
      row['id'],
      row['name'],
      row['phone'],
      row['note'],
      row['created_at'],
      row['updated_at'],
      row['deleted_at'],
    ], rowIndex);
  }

  // Loan Operations
  Future<void> appendLoan(String spreadsheetId, Loan loan) async {
    try {
      final api = await _api;
      final row = loan.toSheetRow();
      final values = [
        [
          row['id'],
          row['person_id'],
          row['type'],
          row['amount'],
          row['note'],
          row['date'],
          row['is_settlement'],
          row['created_at'],
          row['updated_at'],
          row['deleted_at'],
        ]
      ];

      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        '${SheetConstants.loansSheet}!A2',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      throw SheetsException.writeFailed(e);
    }
  }

  Future<void> updateLoan(
    String spreadsheetId,
    Loan loan,
    int rowIndex,
  ) async {
    final row = loan.toSheetRow();
    await updateRow(spreadsheetId, SheetConstants.loansSheet, [
      row['id'],
      row['person_id'],
      row['type'],
      row['amount'],
      row['note'],
      row['date'],
      row['is_settlement'],
      row['created_at'],
      row['updated_at'],
      row['deleted_at'],
    ], rowIndex);
  }

  Future<String?> getSpreadsheetUrl(String spreadsheetId) async {
    return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
  }
}
