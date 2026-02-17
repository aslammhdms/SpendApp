import 'package:mocktail/mocktail.dart';
import 'package:spendsheet/data/remote/sync_engine.dart';
import 'package:spendsheet/data/local/sync_queue_dao.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

class MockSyncQueueDao extends Mock implements SyncQueueDao {}
