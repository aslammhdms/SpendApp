import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/account.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../models/captured_payment.dart';
import '../providers/wallet_capture_provider.dart';
import '../widgets/captured_payment_card.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../shared/widgets/glass_app_bar.dart';

final _captureAccountsProvider =
    FutureProvider.autoDispose<List<Account>>((ref) async {
  return ref.watch(accountRepositoryProvider).getAll();
});

/// Remembered category and account for each pending payment.
final _suggestionsProvider = FutureProvider.autoDispose
    .family<({String? categoryId, String? accountId}), CapturedPayment>(
        (ref, payment) async {
  final service = ref.watch(walletCaptureServiceProvider);
  return (
    categoryId: await service.suggestedCategoryId(payment),
    accountId: await service.suggestedAccountId(payment),
  );
});

/// Set-up and review inbox for payments captured from Google Wallet.
class WalletCaptureScreen extends ConsumerStatefulWidget {
  const WalletCaptureScreen({super.key});

  @override
  ConsumerState<WalletCaptureScreen> createState() =>
      _WalletCaptureScreenState();
}

class _WalletCaptureScreenState extends ConsumerState<WalletCaptureScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletCaptureProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Android's notification access settings.
    if (state == AppLifecycleState.resumed) {
      ref.read(walletCaptureProvider.notifier).refresh();
    }
  }

  Future<void> _add(
    CapturedPayment payment,
    String categoryId,
    String accountId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(walletCaptureProvider.notifier).confirm(
            payment,
            categoryId: categoryId,
            accountId: accountId,
          );
      HapticFeedback.mediumImpact();
      // The choice just made may now be the suggestion for other payments
      // (same merchant or same card).
      ref.invalidate(_suggestionsProvider);
      await ref.read(dashboardProvider.notifier).refresh();
      await ref
          .read(transactionsProvider.notifier)
          .loadTransactions(refresh: true);
      messenger.showSnackBar(
        SnackBar(content: Text('Added ${payment.displayName}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(walletCaptureProvider);
    final notifier = ref.read(walletCaptureProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Google Wallet payments')),
      body: capture.isLoading
          ? const Center(child: CircularProgressIndicator())
          : !capture.isSupported
              ? const EmptyState(
                  icon: Icons.contactless_outlined,
                  title: 'Available on Android',
                  subtitle:
                      'Capturing Google Wallet payments needs an Android phone.',
                )
              : RefreshIndicator(
                  onRefresh: notifier.refresh,
                  edgeOffset: ScreenInsets.topOf(context),
                  child: ListView(
                    padding: ScreenInsets.of(context, bottom: Space.xxl),
                    children: [
                      _SetupCard(capture: capture, notifier: notifier),
                      if (capture.isEnabled) ...[
                        const OverlineHeader('To review'),
                        if (capture.pending.isEmpty)
                          const Card(
                            margin: EdgeInsets.zero,
                            child: EmptyState(
                              icon: Icons.inbox_outlined,
                              title: 'No payments to review',
                              subtitle:
                                  'Pay with Google Wallet and the payment shows up here.',
                              compact: true,
                            ),
                          )
                        else
                          ..._buildPending(capture.pending),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildPending(List<CapturedPayment> pending) {
    final categories = ref.watch(expenseCategoriesProvider).valueOrNull ?? [];
    final accounts = ref.watch(_captureAccountsProvider).valueOrNull ?? [];
    final currency = ref.watch(settingsProvider).currency;
    final notifier = ref.read(walletCaptureProvider.notifier);

    return [
      for (final payment in pending)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Builder(builder: (context) {
            final suggestion =
                ref.watch(_suggestionsProvider(payment)).valueOrNull;
            return CapturedPaymentCard(
              key: ValueKey(payment.id),
              payment: payment,
              categories: categories,
              accounts: accounts,
              currency: currency,
              suggestedCategoryId: suggestion?.categoryId,
              suggestedAccountId: suggestion?.accountId,
              onAdd: (categoryId, accountId) =>
                  _add(payment, categoryId, accountId),
              onDismiss: () => notifier.dismiss(payment),
            );
          }),
        ),
    ];
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.capture, required this.notifier});

  final WalletCaptureState capture;
  final WalletCaptureNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Capture Google Wallet payments'),
            subtitle: const Text(
              'Payments you make with Google Wallet are listed here to add as expenses.',
            ),
            value: capture.isEnabled,
            onChanged: notifier.setEnabled,
          ),
          if (capture.needsAccess)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One more step: allow notification access for SpendSheet. '
                    'Android asks because the permission covers all '
                    'notifications. SpendSheet only keeps Google Wallet '
                    'payment notifications, reads them on this phone, and '
                    'ignores everything else.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton.icon(
                    onPressed: notifier.openAccessSettings,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Allow notification access'),
                  ),
                ],
              ),
            )
          else if (capture.isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.lg,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Notification access is on. New payments appear below.',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
