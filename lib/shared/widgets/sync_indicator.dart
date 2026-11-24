import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_palette.dart';
import '../../data/remote/sync_engine.dart';
import '../providers/sync_status_provider.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return syncStatus.when(
      data: (status) => _buildIndicator(context, status),
      loading: () => _buildIndicator(context, SyncStatus.idle),
      error: (_, __) => _buildIndicator(context, SyncStatus.error),
    );
  }

  Widget _buildIndicator(BuildContext context, SyncStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final (IconData icon, Color color, String label) = switch (status) {
      SyncStatus.synced => (
          Icons.cloud_done_outlined,
          palette.income,
          'Synced'
        ),
      SyncStatus.syncing => (Icons.sync, scheme.primary, 'Syncing'),
      SyncStatus.pending => (
          Icons.cloud_upload_outlined,
          palette.budgetWarning,
          'Changes waiting to sync'
        ),
      SyncStatus.error => (
          Icons.cloud_off_outlined,
          scheme.error,
          'Sync failed'
        ),
      SyncStatus.idle => (
          Icons.cloud_queue,
          scheme.onSurfaceVariant,
          'Sync idle'
        ),
    };

    final iconWidget = status == SyncStatus.syncing
        ? _AnimatedSyncIcon(icon: icon, color: color)
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(icon, color: color, size: 22),
          );

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: SizedBox(
          height: 48,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}

class _AnimatedSyncIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _AnimatedSyncIcon({
    required this.icon,
    required this.color,
  });

  @override
  State<_AnimatedSyncIcon> createState() => _AnimatedSyncIconState();
}

class _AnimatedSyncIconState extends State<_AnimatedSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RotationTransition(
        turns: _controller,
        child: Icon(widget.icon, color: widget.color, size: 22),
      ),
    );
  }
}
