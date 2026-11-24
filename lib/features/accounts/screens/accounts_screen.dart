import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/account.dart';
import '../../../data/remote/sync_engine.dart';
import '../providers/accounts_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/glass_dialog.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../shared/widgets/glass_app_bar.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountsProvider.notifier).loadAccounts();
      _syncSubscription =
          ref.read(syncEngineProvider).statusStream.listen((status) {
        if (status == SyncStatus.synced && mounted) {
          ref.read(accountsProvider.notifier).loadAccounts();
        }
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Text('Accounts'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(state.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(accountsProvider.notifier).loadAccounts(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  edgeOffset: ScreenInsets.topOf(context),
                  onRefresh: () async {
                    await ref.read(accountsProvider.notifier).loadAccounts();
                  },
                  child: ListView(
                    padding: ScreenInsets.of(
                      context,
                      bottom: Space.fabClearance,
                    ),
                    children: [
                      // Total Balance Card
                      _TotalBalanceCard(
                        total: state.totalBalance,
                        currency: currency,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Your Accounts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (state.accounts.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(height: 12),
                                const Text('No accounts yet'),
                              ],
                            ),
                          ),
                        )
                      else
                        ...state.accounts.map((account) => Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm),
                              child: _AccountCard(
                                account: account,
                                onTap: () => context
                                    .push('/accounts/edit/${account.id}'),
                                onDelete: () => _confirmDelete(account.id),
                              ),
                            )),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }

  void _confirmDelete(String accountId) {
    showDialog(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure? This will not delete transactions, but they will be orphaned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(accountsProvider.notifier)
                  .deleteAccount(accountId);
              if (mounted) {
                ref.read(dashboardProvider.notifier).refresh();
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _AccountCard({
    required this.account,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md + 2,
          ),
          child: Row(
            children: [
              CategoryIcon(emoji: account.icon, color: Color(account.color)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _getAccountTypeLabel(account.type),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              MoneyText(
                account.currentBalance,
                currency: account.currency,
                semanticLabel: '${account.name} balance',
                // Positive balances are neutral; only a negative one is a
                // warning signal.
                color: account.currentBalance >= 0
                    ? Theme.of(context).colorScheme.onSurface
                    : context.palette.expense,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.credit:
        return 'Credit Card';
      case AccountType.savings:
        return 'Savings';
      case AccountType.investment:
        return 'Investment';
      case AccountType.wallet:
        return 'Digital Wallet';
      case AccountType.other:
        return 'Other';
    }
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.total, required this.currency});

  final double total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final formatted = CurrencyUtils.format(total, currencyCode: currency);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: Radii.xlAll,
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          Semantics(
            label: 'Total balance, $formatted',
            excludeSemantics: true,
            child: Text(formatted, style: text.displaySmall?.tabular),
          ),
        ],
      ),
    );
  }
}
