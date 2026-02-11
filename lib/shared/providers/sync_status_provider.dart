import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/sync_engine.dart';
import '../../features/home/providers/dashboard_provider.dart';

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  return syncEngine.statusStream;
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final syncEngine = ref.watch(syncEngineProvider);
  return await syncEngine.getPendingCount();
});
