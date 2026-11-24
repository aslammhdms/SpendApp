import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/remote/sync_engine.dart';

class SyncStatusTile extends StatelessWidget {
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final VoidCallback? onSync;

  const SyncStatusTile({
    super.key,
    required this.status,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildStatusIcon(context),
      title: Text(_getStatusTitle()),
      subtitle: Text(_getStatusSubtitle()),
      trailing: status == SyncStatus.syncing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onSync,
              child: const Text('Sync Now'),
            ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = context.palette.income;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Theme.of(context).colorScheme.primary;
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload;
        color = context.palette.budgetWarning;
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = Theme.of(context).colorScheme.error;
        break;
      case SyncStatus.idle:
        icon = Icons.cloud_queue;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _getStatusTitle() {
    switch (status) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.pending:
        return 'Changes Pending';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.idle:
        return 'Not synced';
    }
  }

  String _getStatusSubtitle() {
    if (status == SyncStatus.pending && pendingCount > 0) {
      return '$pendingCount changes waiting to sync';
    }
    if (status == SyncStatus.syncing) {
      return 'Please wait...';
    }
    if (lastSyncAt != null) {
      return 'Last sync: ${AppDateUtils.getRelativeDate(lastSyncAt!)} at ${AppDateUtils.formatDisplayTime(lastSyncAt!)}';
    }
    return 'Tap to sync with Google Sheets';
  }
}
