import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/errors/app_exceptions.dart';

class GoogleAuthService {
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  GoogleSignInAccount? _currentUser;
  auth.AuthClient? _authClient;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });

    try {
      // Add timeout to prevent hanging if Google Play Services is not configured
      _currentUser = await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Silent sign-in timed out');
          return null;
        },
      );
      if (_currentUser != null) {
        await _createAuthClient();
      }
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
      _currentUser = null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _createAuthClient();
        await _saveUserInfo();
      }
      return _currentUser;
    } catch (e) {
      throw AuthException.signInFailed(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _clearStoredCredentials();
      _currentUser = null;
      _authClient = null;
    } catch (e) {
      throw AuthException.signOutFailed(e);
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      await _clearStoredCredentials();
      _currentUser = null;
      _authClient = null;
    } catch (e) {
      throw AuthException.signOutFailed(e);
    }
  }

  Future<auth.AuthClient> getAuthClient() async {
    if (_authClient != null) {
      return _authClient!;
    }

    if (_currentUser == null) {
      throw AuthException.notAuthenticated();
    }

    await _createAuthClient();
    return _authClient!;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (_currentUser == null) {
      throw AuthException.notAuthenticated();
    }

    final authentication = await _currentUser!.authentication;
    return {
      'Authorization': 'Bearer ${authentication.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<String?> getAccessToken() async {
    if (_currentUser == null) return null;

    try {
      final authentication = await _currentUser!.authentication;
      return authentication.accessToken;
    } catch (e) {
      debugPrint('Failed to get access token: $e');
      return null;
    }
  }

  Future<void> _createAuthClient() async {
    if (_currentUser == null) return;

    final authentication = await _currentUser!.authentication;
    final accessToken = authentication.accessToken;
    final idToken = authentication.idToken;

    if (accessToken == null) {
      throw AuthException.tokenExpired();
    }

    final credentials = auth.AccessCredentials(
      auth.AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      _scopes,
      idToken: idToken,
    );

    _authClient = auth.authenticatedClient(
      http.Client(),
      credentials,
    );
  }

  Future<void> refreshToken() async {
    if (_currentUser == null) {
      throw AuthException.notAuthenticated();
    }

    try {
      await _currentUser!.clearAuthCache();
      await _createAuthClient();
    } catch (e) {
      throw AuthException.tokenExpired();
    }
  }

  Future<void> _saveUserInfo() async {
    if (_currentUser == null) return;

    await _secureStorage.write(key: 'user_email', value: _currentUser!.email);
    await _secureStorage.write(key: 'user_name', value: _currentUser!.displayName);
    await _secureStorage.write(key: 'user_photo', value: _currentUser!.photoUrl);
  }

  Future<void> _clearStoredCredentials() async {
    await _secureStorage.delete(key: 'user_email');
    await _secureStorage.delete(key: 'user_name');
    await _secureStorage.delete(key: 'user_photo');
  }

  Future<Map<String, String?>> getStoredUserInfo() async {
    return {
      'email': await _secureStorage.read(key: 'user_email'),
      'name': await _secureStorage.read(key: 'user_name'),
      'photo': await _secureStorage.read(key: 'user_photo'),
    };
  }

  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;
  String? get userPhotoUrl => _currentUser?.photoUrl;
}
