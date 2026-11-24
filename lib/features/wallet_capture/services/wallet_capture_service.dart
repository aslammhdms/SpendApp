import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/local/local_captured_payment_dao.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../models/captured_payment.dart';
import 'wallet_capture_channel.dart';
import 'wallet_notification_parser.dart';
import 'merchant_categorizer.dart';
import '../../../data/models/category.dart';

/// Turns Google Wallet payment notifications into expenses the user confirms.
///
/// Flow: the Android listener queues notifications; [importPending] parses
/// them on the device and stores the payments it recognises; the user then
/// adds each one with a category and account ([confirm]) or dismisses it.
/// The choices are remembered per merchant and per card, so the next payment
/// comes pre-filled.
class WalletCaptureService {
  WalletCaptureService({
    required WalletCaptureChannel channel,
    required LocalCapturedPaymentDao dao,
    required TransactionRepository transactions,
    DateTime Function()? now,
  })  : _channel = channel,
        _dao = dao,
        _transactions = transactions,
        _now = now ?? DateTime.now;

  final WalletCaptureChannel _channel;
  final LocalCapturedPaymentDao _dao;
  final TransactionRepository _transactions;
  final DateTime Function() _now;

  static const _enabledKey = 'wallet_capture.enabled';
  static const _notifyKey = 'wallet_capture.notify';
  static const _categoryRulePrefix = 'wallet_capture.category.';
  static const _accountRulePrefix = 'wallet_capture.account.';

  /// Handled payments are kept this long so a notification Android shows
  /// again is not captured twice.
  static const _keepHandledFor = Duration(days: 30);

  bool get isSupported => _channel.isSupported;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await _channel.setEnabled(enabled);
    // Turning capture off also removes what it has collected.
    if (!enabled) await _dao.deleteAll();
  }

  /// Whether the user wants a reminder after each payment. On by default.
  Future<bool> isNotifyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifyKey) ?? true;
  }

  /// Saves the reminder choice and passes it on to the listener, which
  /// runs without the app. [notificationsAllowed] is the app-wide
  /// Notifications switch, which turns the reminders off too.
  Future<void> setNotifyEnabled(
    bool enabled, {
    required bool notificationsAllowed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyKey, enabled);
    await syncNotify(notificationsAllowed: notificationsAllowed);
  }

  /// Tells the listener whether reminders are on, from the saved choice
  /// and the app-wide Notifications switch.
  Future<void> syncNotify({required bool notificationsAllowed}) async {
    final on = notificationsAllowed && await isNotifyEnabled();
    await _channel.setNotifyEnabled(on);
    if (!on) await _channel.clearPaymentNotifications();
  }

  Future<void> clearPaymentNotifications() =>
      _channel.clearPaymentNotifications();

  Future<bool> hasAccess() => _channel.hasAccess();

  Future<void> openAccessSettings() => _channel.openAccessSettings();

  /// Collects new notifications and stores the payments found in them.
  /// Returns how many new payments were added to the inbox.
  Future<int> importPending() async {
    if (!isSupported || !await isEnabled()) return 0;

    var added = 0;
    for (final raw in await _channel.drain()) {
      final parsed =
          WalletNotificationParser.parse(title: raw.title, text: raw.text);
      if (parsed == null) continue;

      final isNew = await _dao.insertIfNew(CapturedPayment(
        id: _idFor(raw),
        title: raw.title,
        body: raw.text,
        amount: parsed.amount,
        currency: parsed.currency,
        merchant: parsed.merchant,
        cardLast4: parsed.cardLast4,
        postedAt: raw.postedAt,
      ));
      if (isNew) added++;
    }

    await _dao.deleteHandledBefore(_now().subtract(_keepHandledFor));
    return added;
  }

  Future<List<CapturedPayment>> getPending() => _dao.getPending();

  Future<int> getPendingCount() => _dao.getPendingCount();

  /// Records [payment] as an expense and remembers the choices for next time.
  Future<Transaction> confirm(
    CapturedPayment payment, {
    required String categoryId,
    required String accountId,
  }) async {
    // Added or dismissed in the meantime (a second tap, another screen):
    // do not record the same payment twice.
    final current = await _dao.getById(payment.id);
    if (current == null || current.status != CaptureStatus.pending) {
      throw StateError('This payment was already handled.');
    }

    final transaction = await _transactions.create(
      amount: payment.amount,
      type: TransactionType.expense,
      categoryId: categoryId,
      accountId: accountId,
      date: payment.postedAt,
      note: payment.displayName,
    );
    await _dao.markAdded(payment.id, transaction.id);

    final prefs = await SharedPreferences.getInstance();
    final merchantKey = _merchantKey(payment);
    if (merchantKey != null) {
      await prefs.setString('$_categoryRulePrefix$merchantKey', categoryId);
      // The choice now lives under the looser key; drop the exact-name one
      // an earlier version stored, so it cannot disagree.
      final legacyKey = _legacyMerchantKey(payment);
      if (legacyKey != null && legacyKey != merchantKey) {
        await prefs.remove('$_categoryRulePrefix$legacyKey');
      }
    }
    if (payment.cardLast4 != null) {
      await prefs.setString('$_accountRulePrefix${payment.cardLast4}', accountId);
    }
    return transaction;
  }

  Future<void> dismiss(CapturedPayment payment) => _dao.markDismissed(payment.id);

  /// The category to pre-select for [payment], or null.
  ///
  /// What the person chose before comes first: the same merchant, then one
  /// whose name starts the same way ("Starbucks" and "Starbucks Dubai
  /// Mall"). Failing that, a guess from the words in the merchant's name.
  ///
  /// Pass the expense [categories] to get guesses, and to leave out a
  /// remembered category that no longer exists.
  Future<String?> suggestedCategoryId(
    CapturedPayment payment, {
    List<Category> categories = const [],
  }) async {
    final merchantKey = _merchantKey(payment);
    if (merchantKey == null) return null;
    final prefs = await SharedPreferences.getInstance();
    bool exists(String? id) =>
        id != null && (categories.isEmpty || categories.any((c) => c.id == id));

    final legacyKey = _legacyMerchantKey(payment);
    for (final key in [merchantKey, if (legacyKey != null) legacyKey]) {
      final remembered = prefs.getString('$_categoryRulePrefix$key');
      if (exists(remembered)) return remembered;
    }

    // A merchant seen before under a slightly different name. The longest
    // remembered name wins, as the closest match.
    String? closest;
    var closestLength = 0;
    for (final prefKey in prefs.getKeys()) {
      if (!prefKey.startsWith(_categoryRulePrefix)) continue;
      final known = prefKey.substring(_categoryRulePrefix.length);
      if (known.length > closestLength &&
          MerchantCategorizer.sameMerchant(known, merchantKey) &&
          exists(prefs.getString(prefKey))) {
        closest = prefs.getString(prefKey);
        closestLength = known.length;
      }
    }
    if (closest != null) return closest;

    return MerchantCategorizer.categoryIdFor(payment.merchant!, categories);
  }

  /// The account last used for this card, if any.
  Future<String?> suggestedAccountId(CapturedPayment payment) async {
    if (payment.cardLast4 == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_accountRulePrefix${payment.cardLast4}');
  }

  /// The key choices are remembered under: the merchant's name without
  /// company words and branch numbers.
  static String? _merchantKey(CapturedPayment payment) {
    final merchant = payment.merchant?.trim();
    if (merchant == null || merchant.isEmpty) return null;
    final key = MerchantCategorizer.key(merchant);
    return key.isEmpty ? null : key;
  }

  /// The key earlier versions used: the exact name in lower case.
  static String? _legacyMerchantKey(CapturedPayment payment) {
    final merchant = payment.merchant?.trim().toLowerCase();
    return merchant == null || merchant.isEmpty ? null : merchant;
  }

  /// Android can post the same notification more than once (for example
  /// when it updates). Identical notifications within two minutes share an
  /// ID and are stored once; a later, separate payment gets its own.
  static String _idFor(RawWalletNotification raw) {
    final bucket = raw.postedAt.millisecondsSinceEpoch ~/ 120000;
    return '${raw.key}|${raw.title}|${raw.text}|$bucket';
  }
}
