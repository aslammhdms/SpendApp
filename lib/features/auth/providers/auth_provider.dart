import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../data/remote/google_auth_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../services/account_session.dart';
import '../services/sign_in_error.dart';
import 'account_session_provider.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleAuthService _authService;
  final AccountSession? _session;

  AuthNotifier(this._authService, {AccountSession? session})
      : _session = session,
        super(AuthState.initial);

  /// Why the last [signIn] did not succeed, worded for the person using the
  /// app. Null after a successful sign-in.
  String? get signInError => _signInError;
  String? _signInError;

  GoogleSignInAccount? get currentUser => _authService.currentUser;
  bool get isSignedIn => _authService.isSignedIn;
  String? get userEmail => _authService.userEmail;
  String? get userName => _authService.userName;
  String? get userPhotoUrl => _authService.userPhotoUrl;

  Future<void> init() async {
    state = AuthState.loading;
    try {
      await _authService.init();
      final user = _authService.currentUser;
      if (user != null) {
        // A sign-in that never finished its ownership check counts as a
        // new account choosing to sign in, not as a restored session.
        final unfinished = await _hasUnfinishedSignIn();
        await _session?.onSignedIn(user.id, interactive: unfinished);
        await _setUnfinishedSignIn(false);
      }
      state = _authService.isSignedIn
          ? AuthState.authenticated
          : AuthState.unauthenticated;
    } catch (e) {
      state = AuthState.unauthenticated;
    }
  }

  Future<bool> signIn() async {
    state = AuthState.loading;
    _signInError = null;
    try {
      // Set until the ownership check below finishes, so an app killed in
      // between does not later restore this account onto someone else's
      // data.
      await _setUnfinishedSignIn(true);
      final user = await _authService.signIn();
      if (user != null) {
        // Before anything is shown: make sure the data on this device
        // belongs to the account that just signed in.
        try {
          await _session?.onSignedIn(user.id, interactive: true);
        } catch (_) {
          // Do not leave Google signed in to an account whose ownership
          // check failed.
          try {
            await _authService.signOut();
          } catch (e) {
            debugPrint('Sign-out after a failed sign-in failed: $e');
          }
          rethrow;
        }
        await _setUnfinishedSignIn(false);
        state = AuthState.authenticated;
        return true;
      } else {
        // Google returns no account when the picker is dismissed.
        await _setUnfinishedSignIn(false);
        _signInError = signInCancelledMessage;
        state = AuthState.unauthenticated;
        return false;
      }
    } catch (e) {
      final cause = e is AppException ? e.originalError : e;
      debugPrint('Google sign-in failed: $cause');
      // Keep the marker only while Google still holds an account whose
      // ownership check did not finish.
      if (!_authService.isSignedIn) await _setUnfinishedSignIn(false);
      _signInError = signInErrorMessage(e);
      state = AuthState.error;
      return false;
    }
  }

  static const _unfinishedSignInKey = 'auth.unfinished_sign_in';

  Future<bool> _hasUnfinishedSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_unfinishedSignInKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setUnfinishedSignIn(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(_unfinishedSignInKey, true);
      } else {
        await prefs.remove(_unfinishedSignInKey);
      }
    } catch (e) {
      debugPrint('Recording the sign-in state failed: $e');
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading;
    try {
      await _session?.onSigningOut();
      await _authService.signOut();
      _session?.onSignedOut();
      state = AuthState.unauthenticated;
    } catch (e) {
      state = AuthState.error;
    }
  }

  Future<void> disconnect() async {
    state = AuthState.loading;
    try {
      await _session?.onSigningOut();
      await _authService.disconnect();
      _session?.onSignedOut();
      state = AuthState.unauthenticated;
    } catch (e) {
      state = AuthState.error;
    }
  }
}

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return AuthNotifier(
    authService,
    session: ref.watch(accountSessionProvider),
  );
});

final currentUserProvider = Provider<GoogleSignInAccount?>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return authService.currentUser;
});
