import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendsheet/core/constants/category_defaults.dart';
import 'package:spendsheet/core/constants/sheet_constants.dart';
import 'package:spendsheet/core/errors/app_exceptions.dart';
import 'package:spendsheet/data/remote/google_auth_service.dart';
import 'package:spendsheet/data/remote/sheets_service.dart';

/// Signs every request with a dummy token and sends it to [client].
class _FakeAuthService extends GoogleAuthService {
  final http.Client client;

  _FakeAuthService(this.client);

  @override
  Future<auth.AuthClient> getAuthClient() async {
    return auth.authenticatedClient(
      client,
      auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          'test-token',
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null,
        const [],
      ),
    );
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('createSpendSheet', () {
    test('writes the built-in categories and accounts with their fixed IDs',
        () async {
      final appended = <String, List<List<dynamic>>>{};
      final service =
          SheetsService(_FakeAuthService(MockClient((request) async {
        final path = Uri.decodeFull(request.url.path);
        if (path.endsWith('/v4/spreadsheets')) {
          return _json({'spreadsheetId': 'new-sheet'});
        }
        if (path.endsWith(':append')) {
          final tab = path.split('/values/').last.split('!').first;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          appended[tab] = (body['values'] as List)
              .map((row) => List<dynamic>.from(row as List))
              .toList();
        }
        return _json({});
      })));

      final id = await service.createSpendSheet();

      expect(id, 'new-sheet');
      final categoryIds = [
        for (final row in appended[SheetConstants.categoriesSheet]!) row[0],
      ];
      final accountIds = [
        for (final row in appended[SheetConstants.accountsSheet]!) row[0],
      ];
      expect(categoryIds, [
        for (final d in CategoryDefaults.expenseCategories) d.id,
        for (final d in CategoryDefaults.incomeCategories) d.id,
      ]);
      expect(accountIds, [
        for (final d in CategoryDefaults.defaultAccounts) d.id,
      ]);
      expect(categoryIds, containsAll(['cat_food', 'cat_salary']));
      expect(accountIds, containsAll(['acc_cash', 'acc_bank', 'acc_credit']));
    });
  });

  group('findRowByIdInSheet', () {
    SheetsService serviceAnswering(http.Response Function() respond) {
      return SheetsService(
        _FakeAuthService(MockClient((request) async => respond())),
      );
    }

    test('returns the 1-based row of the ID', () async {
      final service = serviceAnswering(() => _json({
            'values': [
              ['id'],
              ['t1'],
              ['t2'],
            ],
          }));

      expect(
        await service.findRowByIdInSheet('s', 'Transactions', 't2'),
        3,
      );
    });

    test('returns -1 when the ID is not on the sheet', () async {
      final service = serviceAnswering(() => _json({
            'values': [
              ['id'],
              ['t1'],
            ],
          }));

      expect(
        await service.findRowByIdInSheet('s', 'Transactions', 'missing'),
        -1,
      );
    });

    test('throws when the lookup fails, rather than reporting "not found"',
        () async {
      final service = serviceAnswering(() => _json(
            {
              'error': {'code': 503, 'message': 'Service unavailable'},
            },
            503,
          ));

      await expectLater(
        service.findRowByIdInSheet('s', 'Transactions', 't1'),
        throwsA(isA<SheetsException>()),
      );
    });
  });
}
