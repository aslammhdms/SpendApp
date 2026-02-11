import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../data/remote/google_auth_service.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleAuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial);

  GoogleSignInAccount? get currentUser => _authService.currentUser;
  bool get isSignedIn => _authService.isSignedIn;
  String? get userEmail => _authService.userEmail;
  String? get userName => _authService.userName;
  String? get userPhotoUrl => _authService.userPhotoUrl;

  Future<void> init() async {
    state = AuthState.loading;
    try {
      await _authService.init();
      state = _authService.isSignedIn
          ? AuthState.authenticated
          : AuthState.unauthenticated;
    } catch (e) {
      state = AuthState.unauthenticated;
    }
  }

  Future<bool> signIn() async {
    state = AuthState.loading;
    try {
      final user = await _authService.signIn();
      if (user != null) {
        state = AuthState.authenticated;
        return true;
      } else {
        state = AuthState.unauthenticated;
        return false;
      }
    } catch (e) {
      state = AuthState.error;
      return false;
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading;
    try {
      await _authService.signOut();
      state = AuthState.unauthenticated;
    } catch (e) {
      state = AuthState.error;
    }
  }

  Future<void> disconnect() async {
    state = AuthState.loading;
    try {
      await _authService.disconnect();
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
  return AuthNotifier(authService);
});

final currentUserProvider = Provider<GoogleSignInAccount?>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return authService.currentUser;
});
