import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_captured_payment_dao.dart';
import '../../home/providers/dashboard_provider.dart';
import '../models/captured_payment.dart';
import '../services/wallet_capture_channel.dart';
import '../services/wallet_capture_service.dart';

class WalletCaptureState {
  const WalletCaptureState({
    this.isSupported = false,
    this.isEnabled = false,
    this.hasAccess = false,
    this.pending = const [],
    this.isLoading = true,
  });

  /// False on platforms without Google Wallet capture (anything but Android).
  final bool isSupported;

  /// The user turned capture on in SpendSheet.
  final bool isEnabled;

  /// Android's notification access is granted.
  final bool hasAccess;

  /// Payments waiting to be added or dismissed, newest first.
  final List<CapturedPayment> pending;
  final bool isLoading;

  /// Capture is on but cannot work until access is granted.
  bool get needsAccess => isEnabled && !hasAccess;

  WalletCaptureState copyWith({
    bool? isSupported,
    bool? isEnabled,
    bool? hasAccess,
    List<CapturedPayment>? pending,
    bool? isLoading,
  }) {
    return WalletCaptureState(
      isSupported: isSupported ?? this.isSupported,
      isEnabled: isEnabled ?? this.isEnabled,
      hasAccess: hasAccess ?? this.hasAccess,
      pending: pending ?? this.pending,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalletCaptureNotifier extends StateNotifier<WalletCaptureState> {
  WalletCaptureNotifier(this._service) : super(const WalletCaptureState());

  final WalletCaptureService _service;

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
      state = WalletCaptureState(
        isSupported: true,
        isEnabled: enabled,
        hasAccess: hasAccess,
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
  return WalletCaptureNotifier(ref.watch(walletCaptureServiceProvider));
});
