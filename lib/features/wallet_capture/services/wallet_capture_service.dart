import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/local/local_captured_payment_dao.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../models/captured_payment.dart';
import 'wallet_capture_channel.dart';
import 'wallet_notification_parser.dart';

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
  }

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
    }
    if (payment.cardLast4 != null) {
      await prefs.setString('$_accountRulePrefix${payment.cardLast4}', accountId);
    }
    return transaction;
  }

  Future<void> dismiss(CapturedPayment payment) => _dao.markDismissed(payment.id);

  /// The category last used for this merchant, if any.
  Future<String?> suggestedCategoryId(CapturedPayment payment) async {
    final merchantKey = _merchantKey(payment);
    if (merchantKey == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_categoryRulePrefix$merchantKey');
  }

  /// The account last used for this card, if any.
  Future<String?> suggestedAccountId(CapturedPayment payment) async {
    if (payment.cardLast4 == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_accountRulePrefix${payment.cardLast4}');
  }

  static String? _merchantKey(CapturedPayment payment) {
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
