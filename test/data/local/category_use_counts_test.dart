import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/data/local/local_transaction_dao.dart';
import 'package:spendsheet/data/models/transaction.dart';

void main() {
  final dao = LocalTransactionDao();
  final since = DateTime(2026, 8, 19);
  var nextId = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.pathOverride = null;
  });

  setUp(() async {
    await DatabaseHelper.instance.close(); // fresh in-memory database
  });

  Future<String> add(String categoryId, DateTime date) async {
    final id = 't${nextId++}';
    await dao.insert(Transaction(
      id: id,
      date: date,
      amount: 10,
      type: TransactionType.expense,
      categoryId: categoryId,
      accountId: 'acc_cash',
      createdAt: date,
      updatedAt: date,
    ));
    return id;
  }

  test('counts recent transactions per category', () async {
    await add('cat_food', DateTime(2026, 11, 1));
    await add('cat_food', DateTime(2026, 11, 5));
    await add('cat_food', DateTime(2026, 10, 2));
    await add('cat_other_expense', DateTime(2026, 9, 9));

    expect(
      await dao.getCategoryUseCounts(since),
      {'cat_food': 3, 'cat_other_expense': 1},
    );
  });

  test('leaves out transactions from before the window', () async {
    await add('cat_food', DateTime(2026, 8, 18, 23, 59));
    await add('cat_food', since);

    expect(await dao.getCategoryUseCounts(since), {'cat_food': 1});
  });

  test('leaves out deleted transactions', () async {
    await add('cat_food', DateTime(2026, 11, 1));
    final deleted = await add('cat_food', DateTime(2026, 11, 2));
    await dao.softDelete(deleted);

    expect(await dao.getCategoryUseCounts(since), {'cat_food': 1});
  });

  test('is empty when there are no transactions', () async {
    expect(await dao.getCategoryUseCounts(since), isEmpty);
  });
}
