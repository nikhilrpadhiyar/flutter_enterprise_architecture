import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/sync/offline_sync_handler.dart';
import 'package:flutter_enterprise_architecture/domain/entities/sync_state.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/console_logger.dart';
import '../../../helpers/json_fixtures.dart';
import '../../../helpers/task_models.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TaskLocalDataSourceImpl local;
  late OfflineSyncHandler handler;
  final now = DateTime.utc(2026, 10, 2, 12);

  setUp(() {
    db = createTestDatabase();
    local = TaskLocalDataSourceImpl(db);
    handler = OfflineSyncHandler(local, silentLogger(), clock: () => now);
  });
  tearDown(() => db.close());

  fnp.QueuedRequest queued(String? key) => fnp.QueuedRequest(
    id: 'q1',
    seq: 1,
    enqueuedAt: now,
    method: fnp.HttpMethod.post,
    path: 'tasks',
    headers: <String, String>{'Idempotency-Key': ?key},
  );

  fnp.NetworkResponse<Object?> response(Object? body) =>
      fnp.NetworkResponse<Object?>(
        statusCode: 200,
        headers: const <String, List<String>>{},
        data: null,
        bodyBytes: body == null
            ? Uint8List(0)
            : Uint8List.fromList(utf8.encode(jsonEncode(body))),
        request: const fnp.NetworkRequest(
          method: fnp.HttpMethod.post,
          path: 'tasks',
        ),
      );

  Future<void> startCreate() => local.beginChange(
    key: 'k1',
    kind: PendingKind.create,
    task: taskModel(id: 'local-k1'),
    now: now,
  );

  test('a delivered create is replaced by the server task', () async {
    await startCreate();

    handler.onReplayed(queued('k1'), response(taskJson(id: 'srv-1')));
    await handler.idle;

    expect(await local.find('local-k1'), isNull);
    expect((await local.find('srv-1'))!.syncState, SyncState.synced);
    expect(await local.contains('k1'), isFalse);
  });

  test('a delivered delete removes the task', () async {
    await local.saveRemote([taskModel()], now);
    await local.beginDelete(key: 'k1', taskId: 't1');

    handler.onReplayed(queued('k1'), response(null));
    await handler.idle;

    expect(await local.find('t1'), isNull);
  });

  test('a dropped request flags the task as failed', () async {
    await startCreate();

    handler.onDropped(queued('k1'), fnp.DropReason.rejectedByServer);
    await handler.idle;

    expect((await local.find('local-k1'))!.syncState, SyncState.failed);
  });

  test('every drop reason is treated as a failure', () async {
    for (final reason in fnp.DropReason.values) {
      await local.clear();
      await startCreate();
      handler.onDropped(queued('k1'), reason);
      await handler.idle;
      expect(
        (await local.find('local-k1'))!.syncState,
        SyncState.failed,
        reason: reason.name,
      );
    }
  });

  test('reports for requests the user does not own are ignored', () async {
    await startCreate();

    handler.onReplayed(queued('other'), response(taskJson(id: 'srv-1')));
    handler.onDropped(queued('other'), fnp.DropReason.expired);
    handler.onReplayed(queued(null), response(taskJson(id: 'srv-2')));
    await handler.idle;

    expect((await local.find('local-k1'))!.syncState, SyncState.pending);
    expect(await local.find('srv-1'), isNull);
    expect(await local.find('srv-2'), isNull);
  });

  test(
    'a bad response does not stop later reports from being applied',
    () async {
      await startCreate();
      await local.beginChange(
        key: 'k2',
        kind: PendingKind.create,
        task: taskModel(id: 'local-k2'),
        now: now,
      );

      handler.onReplayed(queued('k1'), response(<String, Object?>{'nope': 1}));
      handler.onReplayed(queued('k2'), response(taskJson(id: 'srv-2')));
      await handler.idle;

      expect(await local.find('srv-2'), isNotNull);
    },
  );

  test('reports are applied in the order they arrive', () async {
    await startCreate();

    handler.onReplayed(queued('k1'), response(taskJson(id: 'srv-1')));
    handler.onDropped(queued('k1'), fnp.DropReason.expired);
    await handler.idle;

    // The drop finds the change already completed and does nothing.
    expect((await local.find('srv-1'))!.syncState, SyncState.synced);
  });
}
