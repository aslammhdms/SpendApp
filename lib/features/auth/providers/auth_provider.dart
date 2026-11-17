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
        await _session?.onSignedIn(user.id, interactive: false);
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
      final user = await _authService.signIn();
      if (user != null) {
        // Before anything is shown: make sure the data on this device
        // belongs to the account that just signed in.
        await _session?.onSignedIn(user.id, interactive: true);
        state = AuthState.authenticated;
        return true;
      } else {
        // Google returns no account when the picker is dismissed.
        _signInError = signInCancelledMessage;
        state = AuthState.unauthenticated;
        return false;
      }
    } catch (e) {
      final cause = e is AppException ? e.originalError : e;
      debugPrint('Google sign-in failed: $cause');
      _signInError = signInErrorMessage(e);
      state = AuthState.error;
      return false;
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
