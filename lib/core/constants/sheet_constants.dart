class SheetConstants {
  SheetConstants._();

  // Spreadsheet Settings
  static const String spreadsheetTitle = 'SpendSheet Data';
  static const String appIdentifier = 'SPENDSHEET_V1';

  // Sheet Names
  static const String transactionsSheet = 'Transactions';
  static const String categoriesSheet = 'Categories';
  static const String accountsSheet = 'Accounts';
  static const String budgetsSheet = 'Budgets';
  static const String recurringSheet = 'Recurring';
  static const String settingsSheet = 'Settings';
  static const String metaSheet = '_Meta';
  static const String peopleSheet = 'People';
  static const String loansSheet = 'Loans';
  static const String goalsSheet = 'Goals';

  // Transactions Sheet Columns (0-indexed)
  static const int txnIdCol = 0;
  static const int txnDateCol = 1;
  static const int txnAmountCol = 2;
  static const int txnTypeCol = 3;
  static const int txnCategoryIdCol = 4;
  static const int txnAccountIdCol = 5;
  static const int txnToAccountIdCol = 6;
  static const int txnNoteCol = 7;
  static const int txnReceiptUrlCol = 8;
  static const int txnRecurringIdCol = 9;
  static const int txnCreatedAtCol = 10;
  static const int txnUpdatedAtCol = 11;
  static const int txnDeletedAtCol = 12;
  static const int txnLabelsCol = 13;

  static const List<String> transactionHeaders = [
    'id',
    'date',
    'amount',
    'type',
    'category_id',
    'account_id',
    'to_account_id',
    'note',
    'receipt_url',
    'recurring_id',
    'created_at',
    'updated_at',
    'deleted_at',
    'labels',
  ];

  // Categories Sheet Columns
  static const int catIdCol = 0;
  static const int catNameCol = 1;
  static const int catTypeCol = 2;
  static const int catIconCol = 3;
  static const int catColorCol = 4;
  static const int catOrderCol = 5;
  static const int catCreatedAtCol = 6;
  static const int catUpdatedAtCol = 7;
  static const int catDeletedAtCol = 8;

  static const List<String> categoryHeaders = [
    'id',
    'name',
    'type',
    'icon',
    'color',
    'sort_order',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  // Accounts Sheet Columns
  static const int accIdCol = 0;
  static const int accNameCol = 1;
  static const int accTypeCol = 2;
  static const int accInitialBalanceCol = 3;
  static const int accCurrencyCol = 4;
  static const int accIconCol = 5;
  static const int accColorCol = 6;
  static const int accOrderCol = 7;
  static const int accCreatedAtCol = 8;
  static const int accUpdatedAtCol = 9;
  static const int accDeletedAtCol = 10;

  static const List<String> accountHeaders = [
    'id',
    'name',
    'type',
    'initial_balance',
    'currency',
    'icon',
    'color',
    'sort_order',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  // Budgets Sheet Columns
  static const int budIdCol = 0;
  static const int budNameCol = 1;
  static const int budAmountCol = 2;
  static const int budPeriodCol = 3;
  static const int budCategoryIdCol = 4;
  static const int budStartDateCol = 5;
  static const int budCreatedAtCol = 6;
  static const int budUpdatedAtCol = 7;
  static const int budDeletedAtCol = 8;

  static const List<String> budgetHeaders = [
    'id',
    'name',
    'amount',
    'period',
    'category_id',
    'start_date',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  // Recurring Sheet Columns
  static const int recIdCol = 0;
  static const int recNameCol = 1;
  static const int recAmountCol = 2;
  static const int recTypeCol = 3;
  static const int recCategoryIdCol = 4;
  static const int recAccountIdCol = 5;
  static const int recFrequencyCol = 6;
  static const int recIntervalCol = 7;
  static const int recNextDueDateCol = 8;
  static const int recEndDateCol = 9;
  static const int recNoteCol = 10;
  static const int recIsActiveCol = 11;
  static const int recCreatedAtCol = 12;
  static const int recUpdatedAtCol = 13;
  static const int recDeletedAtCol = 14;

  static const List<String> recurringHeaders = [
    'id',
    'name',
    'amount',
    'type',
    'category_id',
    'account_id',
    'frequency',
    'interval',
    'next_due_date',
    'end_date',
    'note',
    'is_active',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  // Settings Sheet Structure (Key-Value pairs)
  static const int settingsKeyCol = 0;
  static const int settingsValueCol = 1;

  static const List<String> settingsHeaders = ['key', 'value'];

  // Meta Sheet (for app identification and sync tracking)
  static const List<String> metaHeaders = ['key', 'value'];

  // Drive Folder
  static const String receiptsFolderName = 'SpendSheet Receipts';

  // API Ranges
  static String getRange(String sheetName, {int? startRow, int? endRow}) {
    if (startRow != null && endRow != null) {
      return '$sheetName!A$startRow:Z$endRow';
    }
    return '$sheetName!A:Z';
  }

  static String getHeaderRange(String sheetName) {
    return '$sheetName!A1:Z1';
  }

  static String getDataRange(String sheetName) {
    return '$sheetName!A2:Z';
  }

  // People Sheet Columns
  static const int pplIdCol = 0;
  static const int pplNameCol = 1;
  static const int pplPhoneCol = 2;
  static const int pplNoteCol = 3;
  static const int pplCreatedAtCol = 4;
  static const int pplUpdatedAtCol = 5;
  static const int pplDeletedAtCol = 6;

  static const List<String> personHeaders = [
    'id',
    'name',
    'phone',
    'note',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  // Loans Sheet Columns
  static const int loanIdCol = 0;
  static const int loanPersonIdCol = 1;
  static const int loanTypeCol = 2;
  static const int loanAmountCol = 3;
  static const int loanNoteCol = 4;
  static const int loanDateCol = 5;
  static const int loanIsSettlementCol = 6;
  static const int loanCreatedAtCol = 7;
  static const int loanUpdatedAtCol = 8;
  static const int loanDeletedAtCol = 9;

  static const List<String> loanHeaders = [
    'id',
    'person_id',
    'type',
    'amount',
    'note',
    'date',
    'is_settlement',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  // Goals Sheet Columns
  static const List<String> goalHeaders = [
    'id',
    'name',
    'target_amount',
    'saved_amount',
    'target_date',
    'icon',
    'color',
    'created_at',
    'updated_at',
    'deleted_at',
  ];
}
