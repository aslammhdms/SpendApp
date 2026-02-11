abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';
}

class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory AuthException.signInFailed([dynamic error]) => AuthException(
        message: 'Sign in failed. Please try again.',
        code: 'sign_in_failed',
        originalError: error,
      );

  factory AuthException.signOutFailed([dynamic error]) => AuthException(
        message: 'Sign out failed. Please try again.',
        code: 'sign_out_failed',
        originalError: error,
      );

  factory AuthException.tokenExpired() => const AuthException(
        message: 'Your session has expired. Please sign in again.',
        code: 'token_expired',
      );

  factory AuthException.notAuthenticated() => const AuthException(
        message: 'Please sign in to continue.',
        code: 'not_authenticated',
      );
}

class SheetsException extends AppException {
  const SheetsException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory SheetsException.notFound() => const SheetsException(
        message: 'Spreadsheet not found.',
        code: 'spreadsheet_not_found',
      );

  factory SheetsException.accessDenied() => const SheetsException(
        message: 'Access denied. Please check permissions.',
        code: 'access_denied',
      );

  factory SheetsException.rateLimitExceeded() => const SheetsException(
        message: 'Rate limit exceeded. Please try again later.',
        code: 'rate_limit_exceeded',
      );

  factory SheetsException.invalidFormat() => const SheetsException(
        message: 'Invalid spreadsheet format.',
        code: 'invalid_format',
      );

  factory SheetsException.createFailed([dynamic error]) => SheetsException(
        message: 'Failed to create spreadsheet.',
        code: 'create_failed',
        originalError: error,
      );

  factory SheetsException.readFailed([dynamic error]) => SheetsException(
        message: 'Failed to read data from spreadsheet.',
        code: 'read_failed',
        originalError: error,
      );

  factory SheetsException.writeFailed([dynamic error]) => SheetsException(
        message: 'Failed to write data to spreadsheet.',
        code: 'write_failed',
        originalError: error,
      );
}

class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory DatabaseException.initFailed([dynamic error]) => DatabaseException(
        message: 'Failed to initialize database.',
        code: 'init_failed',
        originalError: error,
      );

  factory DatabaseException.queryFailed([dynamic error]) => DatabaseException(
        message: 'Database query failed.',
        code: 'query_failed',
        originalError: error,
      );

  factory DatabaseException.insertFailed([dynamic error]) => DatabaseException(
        message: 'Failed to insert data.',
        code: 'insert_failed',
        originalError: error,
      );

  factory DatabaseException.updateFailed([dynamic error]) => DatabaseException(
        message: 'Failed to update data.',
        code: 'update_failed',
        originalError: error,
      );

  factory DatabaseException.deleteFailed([dynamic error]) => DatabaseException(
        message: 'Failed to delete data.',
        code: 'delete_failed',
        originalError: error,
      );
}

class SyncException extends AppException {
  const SyncException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory SyncException.failed([dynamic error]) => SyncException(
        message: 'Sync failed. Changes saved locally.',
        code: 'sync_failed',
        originalError: error,
      );

  factory SyncException.conflictDetected() => const SyncException(
        message: 'Sync conflict detected.',
        code: 'conflict_detected',
      );

  factory SyncException.noConnection() => const SyncException(
        message: 'No internet connection. Changes saved locally.',
        code: 'no_connection',
      );
}

class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory NetworkException.noConnection() => const NetworkException(
        message: 'No internet connection.',
        code: 'no_connection',
      );

  factory NetworkException.timeout() => const NetworkException(
        message: 'Request timed out. Please try again.',
        code: 'timeout',
      );

  factory NetworkException.serverError([dynamic error]) => NetworkException(
        message: 'Server error. Please try again later.',
        code: 'server_error',
        originalError: error,
      );
}

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code,
    this.fieldErrors,
  });

  factory ValidationException.invalidAmount() => const ValidationException(
        message: 'Please enter a valid amount.',
        code: 'invalid_amount',
      );

  factory ValidationException.requiredField(String fieldName) => ValidationException(
        message: '$fieldName is required.',
        code: 'required_field',
      );

  factory ValidationException.invalidDate() => const ValidationException(
        message: 'Please enter a valid date.',
        code: 'invalid_date',
      );
}
