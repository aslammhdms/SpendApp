import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendsheet/data/remote/drive_service.dart';
import 'package:spendsheet/data/remote/google_auth_service.dart';

/// Signs requests with whichever dummy account is current.
class _Auth extends GoogleAuthService {
  _Auth(this.backend);
  final http.Client backend;
  String token = 'token-a';

  @override
  Future<auth.AuthClient> getAuthClient() async => auth.authenticatedClient(
        backend,
        auth.AccessCredentials(
          auth.AccessToken('Bearer', token,
              DateTime.now().toUtc().add(const Duration(hours: 1))),
          null,
          const ['scope'],
        ),
      );
}

void main() {
  test('Drive requests follow the account that is signed in now', () async {
    final seen = <String>[];
    final backend = MockClient((request) async {
      seen.add(request.headers['authorization'] ?? '');
      return http.Response(jsonEncode({'files': []}), 200,
          headers: {'content-type': 'application/json'});
    });
    final authService = _Auth(backend);
    final drive = DriveService(authService);

    await drive.searchForSpendSheets();
    authService.token = 'token-b'; // another account signs in
    await drive.searchForSpendSheets();

    expect(seen, ['Bearer token-a', 'Bearer token-b']);
  });

  test('only spreadsheets owned by the signed-in account are listed',
      () async {
    String? query;
    final backend = MockClient((request) async {
      query = request.url.queryParameters['q'];
      return http.Response(jsonEncode({'files': []}), 200,
          headers: {'content-type': 'application/json'});
    });

    await DriveService(_Auth(backend)).searchForSpendSheets();

    expect(query, contains("'me' in owners"));
    expect(query, contains('trashed=false'));
  });
}
