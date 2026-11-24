import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/data/local/local_goal_dao.dart';
import 'package:spendsheet/data/local/local_transaction_dao.dart';

import '../../helpers/test_database_helper.dart';

void main() {
  late Directory dir;

  setUpAll(initTestDatabase);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('spendsheet_v5');
    DatabaseHelper.pathOverride = p.join(dir.path, 'app.db');
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.pathOverride = null;
    await dir.delete(recursive: true);
  });

  test('a version 4 database gains labels and goals, keeping its rows',
      () async {
    // The transactions table as version 4 left it, with one row.
    final old = await databaseFactoryFfi.openDatabase(
      DatabaseHelper.pathOverride!,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY, date TEXT NOT NULL, amount REAL NOT NULL,
              type TEXT NOT NULL, category_id TEXT NOT NULL,
              account_id TEXT NOT NULL, to_account_id TEXT, note TEXT,
              receipt_url TEXT, recurring_id TEXT, created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL, deleted_at TEXT
            )
          ''');
          await db.insert('transactions', {
            'id': 't1',
            'date': '2026-01-01T00:00:00.000',
            'amount': 5.0,
            'type': 'expense',
            'category_id': 'cat_food',
            'account_id': 'acc_cash',
            'created_at': '2026-01-01T00:00:00.000',
            'updated_at': '2026-01-01T00:00:00.000',
          });
        },
      ),
    );
    await old.close();

    final kept = await LocalTransactionDao().getById('t1');
    expect(kept?.amount, 5.0);
    expect(kept?.labels, isEmpty);
    expect(await LocalGoalDao().getAll(), isEmpty);
    expect(await (await DatabaseHelper.instance.database).getVersion(), 5);
  });
}
