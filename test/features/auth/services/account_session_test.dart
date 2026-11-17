import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendsheet/core/constants/category_defaults.dart';
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/features/auth/services/account_data_service.dart';
import 'package:spendsheet/features/auth/services/account_session.dart';

void main() {
  late AccountDataService data;
  late List<String> calls;
  late AccountSession session;
  Object? pushError;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.pathOverride = null;
  });

  Future<void> addTransaction(String id) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime(2026, 11, 17).toIso8601String();
    await db.insert('transactions', {
      'id': id,
      'date': now,
      'amount': 12.5,
      'type': 'expense',
      'category_id': CategoryDefaults.expenseCategories.first.id,
      'account_id': CategoryDefaults.defaultAccounts.first.id,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> count(String table) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return rows.first['n'] as int;
  }

  /// The device as account [owner] leaves it: one transaction, a custom
  /// category, a queued change, a spreadsheet link and remembered choices.
  Future<void> seedDataOwnedBy(String? owner) async {
    SharedPreferences.setMockInitialValues({
      if (owner != null) 'account.owner_id': owner,
      'settings_spreadsheet_id': 'sheet-of-first-account',
      'settings_spreadsheet_url': 'https://example.test/sheet',
      'settings_last_sync_at': '2026-11-17T10:00:00.000',
      'settings_theme_mode': 'dark',
      'settings_currency': 'AED',
      'budget_alert.b1.2026-11-01': 100,
      'wallet_capture.category.blue bottle': 'cat-coffee',
      'wallet_capture.account.1234': 'acc-visa',
      'wallet_capture.enabled': true,
    });
    await addTransaction('t1');
    final db = await DatabaseHelper.instance.database;
    final now = DateTime(2026, 11, 17).toIso8601String();
    await db.insert('categories', {
      'id': 'cat-coffee',
      'name': 'Coffee',
      'type': 'expense',
      'icon': '☕',
      'color': 0xFF795548,
      'sort_order': 99,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('sync_queue', {
      'entity_type': 'transaction',
      'entity_id': 't1',
      'operation': 'create',
      'data': '{}',
      'created_at': now,
    });
  }

  setUp(() async {
    await DatabaseHelper.instance.close(); // fresh in-memory database
    calls = [];
    pushError = null;
    data = AccountDataService();
    session = AccountSession(
      data: data,
      pushPendingChanges: () async {
        calls.add('push');
        if (pushError != null) throw pushError!;
      },
      stopSync: () async => calls.add('stopSync'),
      discardCapturedNotifications: () async => calls.add('discardCaptured'),
      resetAppState: () => calls.add('resetState'),
    );
  });

  group('signing in', () {
    test('keeps the data when the same account signs in again', () async {
      await seedDataOwnedBy('account-a');

      final cleared = await session.onSignedIn('account-a', interactive: true);

      expect(cleared, isFalse);
      expect(await count('transactions'), 1);
      expect(await count('sync_queue'), 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_spreadsheet_id'),
          'sheet-of-first-account');
      expect(calls, isEmpty);
    });

    test('removes the previous account\'s data when another signs in',
        () async {
      await seedDataOwnedBy('account-a');

      final cleared = await session.onSignedIn('account-b', interactive: true);

      expect(cleared, isTrue);
      expect(await count('transactions'), 0);
      expect(await count('sync_queue'), 0,
          reason: 'queued changes must not reach the new account\'s sheet');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_spreadsheet_id'), isNull,
          reason: 'the new account must set up its own spreadsheet');
      expect(prefs.getString('settings_spreadsheet_url'), isNull);
      expect(prefs.getString('settings_last_sync_at'), isNull);
      expect(prefs.get('budget_alert.b1.2026-11-01'), isNull);
      expect(prefs.get('wallet_capture.category.blue bottle'), isNull);
      expect(prefs.get('wallet_capture.account.1234'), isNull);
      expect(await data.ownerId(), 'account-b');
    });

    test('leaves the app as a fresh install after removing data', () async {
      await seedDataOwnedBy('account-a');

      await session.onSignedIn('account-b', interactive: true);

      final db = await DatabaseHelper.instance.database;
      final categories = await db.query('categories');
      expect(
        categories.map((c) => c['id']).toSet(),
        {
          ...CategoryDefaults.expenseCategories.map((c) => c.id),
          ...CategoryDefaults.incomeCategories.map((c) => c.id),
        },
        reason: 'defaults restored, the custom category gone',
      );
      expect(await count('accounts'), CategoryDefaults.defaultAccounts.length);
    });

    test('keeps device preferences when removing data', () async {
      await seedDataOwnedBy('account-a');

      await session.onSignedIn('account-b', interactive: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_theme_mode'), 'dark');
      expect(prefs.getString('settings_currency'), 'AED');
      expect(prefs.getBool('wallet_capture.enabled'), isTrue);
    });

    test('stops syncing before removing data, then resets what is loaded',
        () async {
      await seedDataOwnedBy('account-a');

      await session.onSignedIn('account-b', interactive: true);

      expect(calls, ['stopSync', 'discardCaptured', 'resetState']);
    });

    test('removes data with no recorded owner on an interactive sign-in',
        () async {
      await seedDataOwnedBy(null);

      final cleared = await session.onSignedIn('account-b', interactive: true);

      expect(cleared, isTrue);
      expect(await count('transactions'), 0);
      expect(await data.ownerId(), 'account-b');
    });

    test('leaves data with no recorded owner alone when restoring a session',
        () async {
      await seedDataOwnedBy(null);

      final cleared =
          await session.onSignedIn('account-a', interactive: false);

      expect(cleared, isFalse);
      expect(await count('transactions'), 1);
      expect(await data.ownerId(), isNull,
          reason: 'ownership is still unproven');
    });

    test('removes another account\'s data even when restoring a session',
        () async {
      await seedDataOwnedBy('account-a');

      final cleared =
          await session.onSignedIn('account-b', interactive: false);

      expect(cleared, isTrue);
      expect(await count('transactions'), 0);
    });

    test('records the owner on a first sign-in', () async {
      SharedPreferences.setMockInitialValues({});

      await session.onSignedIn('account-a', interactive: true);

      expect(await data.ownerId(), 'account-a');
    });
  });

  group('signing out', () {
    test('sends unsynced changes, then stops syncing', () async {
      await seedDataOwnedBy('account-a');

      await session.onSigningOut();

      expect(calls, ['push', 'stopSync']);
    });

    test('still stops syncing when the last sync fails', () async {
      await seedDataOwnedBy('account-a');
      pushError = Exception('offline');

      await session.onSigningOut();

      expect(calls, ['push', 'stopSync']);
    });

    test('keeps the data and its owner on the device', () async {
      await seedDataOwnedBy('account-a');

      await session.onSigningOut();
      session.onSignedOut();

      expect(await count('transactions'), 1);
      expect(await data.ownerId(), 'account-a');
      expect(calls.last, 'resetState');
    });
  });
}
