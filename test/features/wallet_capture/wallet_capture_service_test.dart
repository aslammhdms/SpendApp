import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:spendsheet/data/local/database_helper.dart';
import 'package:spendsheet/data/local/local_captured_payment_dao.dart';
import 'package:spendsheet/data/local/local_transaction_dao.dart';
import 'package:spendsheet/data/local/sync_queue_dao.dart';
import 'package:spendsheet/data/repositories/transaction_repository.dart';
import 'package:spendsheet/features/wallet_capture/models/captured_payment.dart';
import 'package:spendsheet/features/wallet_capture/services/wallet_capture_channel.dart';
import 'package:spendsheet/features/wallet_capture/services/wallet_capture_service.dart';

import '../../helpers/mock_sync_engine.dart';
import '../../helpers/test_database_helper.dart';
import 'package:spendsheet/data/local/local_category_dao.dart';
import 'package:spendsheet/data/models/category.dart';

/// Stands in for the Android notification listener.
class _FakeChannel implements WalletCaptureChannel {
  bool supported = true;
  bool access = true;
  bool? enabledOnDevice;
  final List<RawWalletNotification> queued = [];

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<void> setEnabled(bool enabled) async => enabledOnDevice = enabled;

  @override
  Future<List<RawWalletNotification>> drain() async {
    final items = List.of(queued);
    queued.clear();
    return items;
  }
}

RawWalletNotification _note(
  String title,
  String text, {
  String key = 'wallet|1',
  DateTime? at,
}) {
  return RawWalletNotification(
    key: key,
    title: title,
    text: text,
    postedAt: at ?? DateTime(2026, 11, 17, 9, 30),
  );
}

void main() {
  late _FakeChannel channel;
  late LocalCapturedPaymentDao dao;
  late LocalTransactionDao transactionDao;
  late WalletCaptureService service;
  var now = DateTime(2026, 11, 17, 10);

  setUpAll(() {
    initTestDatabase();
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() {
    DatabaseHelper.pathOverride = null;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.close(); // fresh in-memory database
    now = DateTime(2026, 11, 17, 10);

    final syncEngine = MockSyncEngine();
    when(() => syncEngine.queueOperation(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});

    channel = _FakeChannel();
    dao = LocalCapturedPaymentDao();
    transactionDao = LocalTransactionDao();
    service = WalletCaptureService(
      channel: channel,
      dao: dao,
      transactions: TransactionRepository(
        localDao: transactionDao,
        syncQueueDao: SyncQueueDao(),
        syncEngine: syncEngine,
      ),
      now: () => now,
    );
    await service.setEnabled(true);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('importing notifications', () {
    test('a payment notification lands in the inbox', () async {
      channel.queued
          .add(_note('Blue Bottle Coffee', r'$5.40 with Visa ••1234'));

      expect(await service.importPending(), 1);

      final pending = await service.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.merchant, 'Blue Bottle Coffee');
      expect(pending.single.amount, 5.40);
      expect(pending.single.cardLast4, '1234');
      expect(pending.single.status, CaptureStatus.pending);
    });

    test('notifications that are not payments are ignored', () async {
      channel.queued.addAll([
        _note('Your card is ready', 'Visa ••1234 was added to Wallet'),
        _note('Blue Bottle', r'$5.40 payment declined', key: 'wallet|2'),
      ]);

      expect(await service.importPending(), 0);
      expect(await service.getPending(), isEmpty);
    });

    test('the same notification posted twice is stored once', () async {
      final first = _note('Shop', r'$9.00 with Visa ••1234');
      channel.queued.add(first);
      await service.importPending();

      channel.queued.add(_note(
        'Shop',
        r'$9.00 with Visa ••1234',
        at: first.postedAt.add(const Duration(seconds: 20)),
      ));
      expect(await service.importPending(), 0);
      expect(await service.getPendingCount(), 1);
    });

    test('a second identical purchase later is its own payment', () async {
      channel.queued.add(_note('Shop', r'$9.00 with Visa ••1234'));
      await service.importPending();

      channel.queued.add(_note(
        'Shop',
        r'$9.00 with Visa ••1234',
        at: DateTime(2026, 11, 17, 13),
      ));
      expect(await service.importPending(), 1);
      expect(await service.getPendingCount(), 2);
    });

    test('nothing is collected while capture is off', () async {
      await service.setEnabled(false);
      channel.queued.add(_note('Shop', r'$9.00 with Visa ••1234'));

      expect(await service.importPending(), 0);
      expect(channel.enabledOnDevice, isFalse);
      expect(channel.queued, hasLength(1), reason: 'left for when it is on');
    });

    test('nothing happens on platforms without capture', () async {
      channel.supported = false;
      channel.queued.add(_note('Shop', r'$9.00 with Visa ••1234'));

      expect(await service.importPending(), 0);
    });
  });

  group('reviewing a payment', () {
    late CapturedPayment payment;

    setUp(() async {
      channel.queued
          .add(_note('Blue Bottle Coffee', r'$5.40 with Visa ••1234'));
      await service.importPending();
      payment = (await service.getPending()).single;
    });

    test('adding it creates an expense and clears it from the inbox',
        () async {
      final transaction = await service.confirm(
        payment,
        categoryId: 'cat_food',
        accountId: 'acc_credit',
      );

      final saved = await transactionDao.getById(transaction.id);
      expect(saved, isNotNull);
      expect(saved!.amount, 5.40);
      expect(saved.isExpense, isTrue);
      expect(saved.categoryId, 'cat_food');
      expect(saved.accountId, 'acc_credit');
      expect(saved.note, 'Blue Bottle Coffee');
      expect(saved.date, payment.postedAt);

      expect(await service.getPending(), isEmpty);
      final stored = await dao.getById(payment.id);
      expect(stored!.status, CaptureStatus.added);
      expect(stored.transactionId, transaction.id);
    });

    test('adding it a second time is refused', () async {
      await service.confirm(payment,
          categoryId: 'cat_food', accountId: 'acc_credit');

      await expectLater(
        service.confirm(payment,
            categoryId: 'cat_food', accountId: 'acc_credit'),
        throwsStateError,
      );
      expect(await transactionDao.getAll(), hasLength(1));
    });

    test('turning capture off removes what was collected', () async {
      await service.setEnabled(false);

      expect(await dao.getById(payment.id), isNull);
    });

    test('dismissing it clears it without creating an expense', () async {
      await service.dismiss(payment);

      expect(await service.getPending(), isEmpty);
      expect(await transactionDao.getAll(), isEmpty);
    });

    test('a handled payment is not captured again', () async {
      await service.dismiss(payment);

      channel.queued
          .add(_note('Blue Bottle Coffee', r'$5.40 with Visa ••1234'));
      expect(await service.importPending(), 0);
      expect(await service.getPending(), isEmpty);
    });

    test('the category and account are remembered for next time', () async {
      expect(await service.suggestedCategoryId(payment), isNull);
      expect(await service.suggestedAccountId(payment), isNull);

      await service.confirm(payment,
          categoryId: 'cat_food', accountId: 'acc_credit');

      channel.queued.add(_note(
        'BLUE BOTTLE COFFEE',
        r'$7.10 with Visa ••1234',
        key: 'wallet|9',
        at: DateTime(2026, 11, 18, 8),
      ));
      await service.importPending();
      final next = (await service.getPending()).single;

      expect(await service.suggestedCategoryId(next), 'cat_food');
      expect(await service.suggestedAccountId(next), 'acc_credit');
    });
  });

  group('suggesting a category', () {
    late List<Category> categories;

    /// Captures one payment and returns it.
    Future<CapturedPayment> capture(String title, String text,
        {String key = 'wallet|s'}) async {
      channel.queued.add(_note(title, text, key: key));
      await service.importPending();
      return (await service.getPending())
          .firstWhere((p) => p.title == title && p.body == text);
    }

    setUp(() async {
      categories = await LocalCategoryDao().getExpenseCategories();
    });

    test('guesses from the merchant name the first time', () async {
      // The real notification the feature was first tried with.
      final payment = await capture(
        'LIFECARE HOSPITAL LLC-',
        'AED 12.37 with ADCB Islamic Debit Mastercard ••1786',
      );

      expect(payment.amount, 12.37);
      expect(payment.cardLast4, '1786');
      expect(
        await service.suggestedCategoryId(payment, categories: categories),
        'cat_health',
      );
    });

    test('gives nothing for a name it cannot place', () async {
      final payment = await capture('AL FUTTAIM LLC', 'AED 80.00');

      expect(
        await service.suggestedCategoryId(payment, categories: categories),
        isNull,
      );
    });

    test('what the person chose beats the guess', () async {
      final first = await capture('LIFECARE HOSPITAL LLC-', 'AED 12.37');
      await service.confirm(first,
          categoryId: 'cat_insurance', accountId: 'acc_cash');

      final next =
          await capture('LIFECARE HOSPITAL LLC-', 'AED 40.00', key: 'w|2');

      expect(
        await service.suggestedCategoryId(next, categories: categories),
        'cat_insurance',
      );
    });

    test('recognises the merchant under a slightly different name',
        () async {
      final first = await capture('Lifecare Hospital', 'AED 12.37');
      await service.confirm(first,
          categoryId: 'cat_insurance', accountId: 'acc_cash');

      for (final (i, name) in [
        'LIFECARE HOSPITAL LLC-',
        'Lifecare Hospital Br 2',
        'LIFECARE HOSPITAL MUSAFFAH',
      ].indexed) {
        final next = await capture(name, 'AED 40.00', key: 'w|n$i');
        expect(
          await service.suggestedCategoryId(next, categories: categories),
          'cat_insurance',
          reason: name,
        );
      }
    });

    test('does not confuse two merchants that share a first word', () async {
      final first = await capture('LIFECARE HOSPITAL', 'AED 12.37');
      await service.confirm(first,
          categoryId: 'cat_insurance', accountId: 'acc_cash');

      final other = await capture('LIFELINE HOSPITAL', 'AED 40.00', key: 'w|2');

      expect(
        await service.suggestedCategoryId(other, categories: categories),
        'cat_health',
        reason: 'guessed afresh, not taken from Lifecare',
      );
    });

    test('falls back to the guess when the remembered category is gone',
        () async {
      final first = await capture('LIFECARE HOSPITAL', 'AED 12.37');
      await service.confirm(first,
          categoryId: 'deleted-category', accountId: 'acc_cash');

      final next = await capture('LIFECARE HOSPITAL', 'AED 40.00', key: 'w|2');

      expect(
        await service.suggestedCategoryId(next, categories: categories),
        'cat_health',
      );
    });

    test('still honours a choice remembered by an earlier version', () async {
      SharedPreferences.setMockInitialValues({
        'wallet_capture.enabled': true,
        // Earlier versions stored the exact name in lower case.
        'wallet_capture.category.lifecare hospital llc-': 'cat_insurance',
      });

      final payment = await capture('LIFECARE HOSPITAL LLC-', 'AED 12.37');

      expect(
        await service.suggestedCategoryId(payment, categories: categories),
        'cat_insurance',
      );
    });
  });

  test('old handled payments are cleaned up, pending ones are kept', () async {
    channel.queued.addAll([
      _note('Old Shop', r'$1.00', key: 'a', at: DateTime(2026, 9, 1)),
      _note('Old Cafe', r'$2.00', key: 'b', at: DateTime(2026, 9, 1)),
    ]);
    await service.importPending();
    final pending = await service.getPending();
    await service.dismiss(pending.firstWhere((p) => p.merchant == 'Old Shop'));

    await service.importPending(); // runs the clean-up

    final left = await service.getPending();
    expect(left.map((p) => p.merchant), ['Old Cafe']);
    expect(
      await dao.getById(pending.firstWhere((p) => p.merchant == 'Old Shop').id),
      isNull,
    );
  });
}
