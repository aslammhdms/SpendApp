import '../../../core/errors/app_exceptions.dart';

/// Turns a failed Google sign-in into a message that says what to do next.
///
/// Google reports sign-in failures as a status code inside the error text
/// ("ApiException: 10"). The codes worth telling apart are the ones the
/// person can fix: a build Google does not recognise, an account that is not
/// allowed in, and no connection.
String signInErrorMessage(Object error) {
  final original = error is AppException ? error.originalError : error;
  final detail = '${original ?? error}';

  final match = RegExp(r'ApiException: (\d+)').firstMatch(detail);
  final status = match == null ? null : int.parse(match.group(1)!);

  if (status == 10 || detail.contains('DEVELOPER_ERROR')) {
    return 'Google does not recognise this copy of the app (error 10). '
        'The key that signed it is not registered in the Google Cloud '
        'project: add its SHA-1 fingerprint and the package name as an '
        'Android OAuth client, wait a few minutes, then try again.';
  }
  if (status == 7 || detail.contains('network_error')) {
    return 'Could not reach Google. Check your internet connection and '
        'try again.';
  }
  if (status == 12500) {
    return 'Google could not sign this account in (error 12500). Check that '
        'the account is a test user on the OAuth consent screen and that '
        'Google Play services is up to date.';
  }
  if (status == 12501 || detail.contains('sign_in_canceled')) {
    return signInCancelledMessage;
  }
  if (status == 12502) {
    return 'A sign-in is already in progress. Wait a moment and try again.';
  }
  if (status != null) {
    return 'Sign in failed (Google error $status). Please try again.';
  }
  return 'Sign in failed. Please try again.';
}

const signInCancelledMessage = 'Sign in was cancelled. Please try again.';
