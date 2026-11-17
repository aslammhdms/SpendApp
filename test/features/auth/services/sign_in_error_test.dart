import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/errors/app_exceptions.dart';
import 'package:spendsheet/features/auth/services/sign_in_error.dart';

PlatformException _apiException(int status) => PlatformException(
      code: 'sign_in_failed',
      message: 'com.google.android.gms.common.api.ApiException: $status: ',
    );

void main() {
  group('signInErrorMessage', () {
    test('explains an unregistered signing key (status 10)', () {
      final message = signInErrorMessage(_apiException(10));

      expect(message, contains('error 10'));
      expect(message, contains('SHA-1'));
    });

    test('reads the cause wrapped in an AuthException', () {
      final message =
          signInErrorMessage(AuthException.signInFailed(_apiException(10)));

      expect(message, contains('SHA-1'));
    });

    test('explains a missing connection (status 7)', () {
      expect(signInErrorMessage(_apiException(7)), contains('internet'));
      expect(
        signInErrorMessage(PlatformException(code: 'network_error')),
        contains('internet'),
      );
    });

    test('points at the consent screen for status 12500', () {
      expect(signInErrorMessage(_apiException(12500)), contains('test user'));
    });

    test('treats status 12501 as a cancelled sign-in', () {
      expect(signInErrorMessage(_apiException(12501)), signInCancelledMessage);
    });

    test('does not mistake status 12501 or 100 for status 10', () {
      expect(signInErrorMessage(_apiException(12501)), isNot(contains('SHA')));
      expect(signInErrorMessage(_apiException(100)), isNot(contains('SHA')));
    });

    test('shows the code for a status it does not know', () {
      expect(signInErrorMessage(_apiException(8)), contains('Google error 8'));
    });

    test('falls back to a plain message when there is no status', () {
      expect(
        signInErrorMessage(Exception('boom')),
        'Sign in failed. Please try again.',
      );
    });
  });
}
