import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/sync_engine.dart';
import '../../features/transactions/providers/transactions_provider.dart';
import '../../features/transactions/screens/add_edit_transaction_screen.dart'
    show accountsWithBalanceProvider;
import '../providers/sync_status_provider.dart';

/// Reloads the cached category and account lists whenever a sync finishes.
///
/// Those lists are read once and kept, which is right while only this
/// device changes them. A sync can change them too: another device added a
/// category, or sync folded a duplicate into its twin. Without this the
/// pickers kept showing the old list until the app was restarted.
class SyncListRefresher extends ConsumerWidget {
  const SyncListRefresher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(syncStatusProvider, (previous, next) {
      if (next.valueOrNull != SyncStatus.synced) return;
      ref.invalidate(categoriesProvider);
      ref.invalidate(expenseCategoriesProvider);
      ref.invalidate(incomeCategoriesProvider);
      ref.invalidate(accountsWithBalanceProvider);
    });
    return child;
  }
}
