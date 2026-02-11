import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/sync_engine.dart';
import '../providers/sync_status_provider.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return syncStatus.when(
      data: (status) => _buildIndicator(status),
      loading: () => _buildIndicator(SyncStatus.idle),
      error: (_, __) => _buildIndicator(SyncStatus.error),
    );
  }

  Widget _buildIndicator(SyncStatus status) {
    IconData icon;
    Color color;
    bool animate = false;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = AppColors.success;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = AppColors.info;
        animate = true;
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload;
        color = AppColors.warning;
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = AppColors.error;
        break;
      case SyncStatus.idle:
      default:
        icon = Icons.cloud_queue;
        color = AppColors.textTertiary;
    }

    if (animate) {
      return _AnimatedSyncIcon(icon: icon, color: color);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(icon, color: color, size: 20),
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
        child: Icon(widget.icon, color: widget.color, size: 20),
      ),
    );
  }
}
