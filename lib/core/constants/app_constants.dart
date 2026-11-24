class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'SpendSheet';
  static const String appVersion = '1.0.0';

  // Sync Settings
  static const Duration syncInterval = Duration(minutes: 15);
  static const Duration batchWriteDelay = Duration(seconds: 5);
  static const int maxRetryAttempts = 3;
  static const Duration retryBaseDelay = Duration(seconds: 1);

  // Pagination
  static const int transactionsPageSize = 50;
  static const int recentTransactionsCount = 10;

  // Image Settings
  static const int maxImageSizeKB = 500;
  static const int imageQuality = 70;

  // Budget Thresholds
  static const double budgetWarningThreshold = 0.8; // 80%
  static const double budgetCriticalThreshold = 1.0; // 100%

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'hh:mm a';
  static const String monthYearFormat = 'MMMM yyyy';

  // Currency Defaults
  static const String defaultCurrencyCode = 'USD';
  static const String defaultCurrencySymbol = '\$';

  // Notification Channels
  static const String budgetNotificationChannel = 'budget_alerts';
  static const String reminderNotificationChannel = 'recurring_reminders';
  static const String summaryNotificationChannel = 'spending_summaries';
}
