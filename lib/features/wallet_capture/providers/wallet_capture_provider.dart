import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_captured_payment_dao.dart';
import '../../onboarding/providers/sheet_setup_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../models/captured_payment.dart';
import '../services/wallet_capture_channel.dart';
import '../services/wallet_capture_service.dart';

class WalletCaptureState {
  const WalletCaptureState({
    this.isSupported = false,
    this.isEnabled = false,
    this.hasAccess = false,
    this.notifyOnPayment = true,
    this.pending = const [],
    this.isLoading = true,
  });

  /// False on platforms without Google Wallet capture (anything but Android).
  final bool isSupported;

  /// The user turned capture on in SpendSheet.
  final bool isEnabled;

  /// Android's notification access is granted.
  final bool hasAccess;

  /// Post a reminder right after each payment.
  final bool notifyOnPayment;

  /// Payments waiting to be added or dismissed, newest first.
  final List<CapturedPayment> pending;
  final bool isLoading;

  /// Capture is on but cannot work until access is granted.
  bool get needsAccess => isEnabled && !hasAccess;

  WalletCaptureState copyWith({
    bool? isSupported,
    bool? isEnabled,
    bool? hasAccess,
    bool? notifyOnPayment,
    List<CapturedPayment>? pending,
    bool? isLoading,
  }) {
    return WalletCaptureState(
      isSupported: isSupported ?? this.isSupported,
      isEnabled: isEnabled ?? this.isEnabled,
      hasAccess: hasAccess ?? this.hasAccess,
      notifyOnPayment: notifyOnPayment ?? this.notifyOnPayment,
      pending: pending ?? this.pending,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalletCaptureNotifier extends StateNotifier<WalletCaptureState> {
  WalletCaptureNotifier(this._service, {Future<bool> Function()? notificationsAllowed})
      : _notificationsAllowed = notificationsAllowed ?? (() async => true),
        super(const WalletCaptureState());

  final WalletCaptureService _service;

  /// The app-wide Notifications switch in Settings.
  final Future<bool> Function() _notificationsAllowed;

  /// Collects newly captured payments and reloads the inbox and status.
  Future<void> refresh() async {
    if (!_service.isSupported) {
      state = const WalletCaptureState(isLoading: false);
      return;
    }
    try {
      final enabled = await _service.isEnabled();
      final hasAccess = enabled && await _service.hasAccess();
      if (hasAccess) await _service.importPending();
      final notify = await _service.isNotifyEnabled();
      await _service.syncNotify(
          notificationsAllowed: await _notificationsAllowed());
      state = WalletCaptureState(
        isSupported: true,
        isEnabled: enabled,
        hasAccess: hasAccess,
        notifyOnPayment: notify,
        pending: await _service.getPending(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isSupported: true, isLoading: false);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await _service.setEnabled(enabled);
    await refresh();
  }

  Future<void> openAccessSettings() => _service.openAccessSettings();

  Future<void> setNotifyOnPayment(bool enabled) async {
    await _service.setNotifyEnabled(enabled,
        notificationsAllowed: await _notificationsAllowed());
    state = state.copyWith(notifyOnPayment: enabled);
  }

  /// Passes a change of the app-wide Notifications switch on to the
  /// listener.
  Future<void> syncNotify() async {
    await _service.syncNotify(
        notificationsAllowed: await _notificationsAllowed());
  }

  /// The person is looking at the list, so the reminders have done their
  /// job.
  Future<void> clearReminders() => _service.clearPaymentNotifications();

  /// Turns capture on and, if Android has not granted notification access
  /// yet, opens the screen where the person grants it. Call only after the
  /// person agreed to the disclosure.
  Future<void> enableAfterConsent() async {
    await setEnabled(true);
    if (state.needsAccess) await openAccessSettings();
  }

  Future<void> confirm(
    CapturedPayment payment, {
    required String categoryId,
    required String accountId,
  }) async {
    await _service.confirm(payment,
        categoryId: categoryId, accountId: accountId);
    _remove(payment);
  }

  Future<void> dismiss(CapturedPayment payment) async {
    await _service.dismiss(payment);
    _remove(payment);
  }

  void _remove(CapturedPayment payment) {
    state = state.copyWith(
      pending: state.pending.where((p) => p.id != payment.id).toList(),
    );
  }
}

final walletCaptureChannelProvider = Provider<WalletCaptureChannel>((ref) {
  return const WalletCaptureChannel();
});

final capturedPaymentDaoProvider = Provider<LocalCapturedPaymentDao>((ref) {
  return LocalCapturedPaymentDao();
});

final walletCaptureServiceProvider = Provider<WalletCaptureService>((ref) {
  return WalletCaptureService(
    channel: ref.watch(walletCaptureChannelProvider),
    dao: ref.watch(capturedPaymentDaoProvider),
    transactions: ref.watch(transactionRepositoryProvider),
  );
});

final walletCaptureProvider =
    StateNotifierProvider<WalletCaptureNotifier, WalletCaptureState>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return WalletCaptureNotifier(
    ref.watch(walletCaptureServiceProvider),
    notificationsAllowed: () async =>
        (await settings.getSettings()).notificationsEnabled,
  );
});
