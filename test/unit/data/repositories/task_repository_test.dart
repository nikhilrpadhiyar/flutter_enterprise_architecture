import 'dart:typed_data';

import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/sync_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/task_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/models/task_model.dart';
import 'package:flutter_enterprise_architecture/data/repositories/sync_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/task_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/entities/sync_state.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_sort.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_task_request.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/sequential_ids.dart';
import '../../../helpers/test_network.dart';

void main() {
  late TestNetwork net;
  late TaskRepositoryImpl repository;
  final fixedNow = DateTime.utc(2026, 10, 2, 12);
  const request = CreateTaskRequest(
    title: 'Write spec',
    projectId: 'p1',
    priority: TaskPriority.high,
  );

  setUp(() async {
    net = TestNetwork();
    await net.signIn();
    repository = TaskRepositoryImpl(
      TaskRemoteDataSource(net.requester),
      net.taskLocal,
      net.logger,
      SequentialIds(),
      clock: () => fixedNow,
    );
  });

  tearDown(() => net.dispose());

  fnp.MockResponse noContent() =>
      fnp.MockResponse.bytes(Uint8List(0), statusCode: 204);

  fnp.MockResponse unreachable() =>
      fnp.MockResponse.failure(const fnp.ConnectionException());

  String? header(fnp.RecordedCall call, String name) => call.headers.entries
      .where((e) => e.key.toLowerCase() == name.toLowerCase())
      .map((e) => e.value)
      .firstOrNull;

  void stubList(List<Object?> items, {int? total}) => net.adapter.onGet(
    TestNetwork.path('tasks'),
    (call) => fnp.MockResponse.json(pageJson(items, total: total)),
  );

  Future<List<String>> listedIds([TaskQuery query = const TaskQuery()]) async =>
      (await repository.getTasks(query)).data.items.map((t) => t.id).toList();

  group('getTasks online', () {
    test(
      'sends paging, search, filters and sort as query parameters',
      () async {
        stubList(<Object?>[taskJson()]);

        await repository.getTasks(
          const TaskQuery(
            page: 2,
            pageSize: 10,
            search: 'spec',
            statuses: {TaskStatus.todo, TaskStatus.inProgress},
            priorities: {TaskPriority.urgent},
            projectId: 'p1',
            sort: TaskSort.dueDateDescending,
          ),
        );

        final query = net.adapter
            .callsTo('/v1/tasks')
            .single
            .uri
            .queryParameters;
        expect(query, <String, String>{
          'page': '2',
          'pageSize': '10',
          'q': 'spec',
          'status': 'inProgress,todo',
          'priority': 'urgent',
          'projectId': 'p1',
          'sort': '-dueDate',
        });
      },
    );

    test('omits empty filters', () async {
      stubList(<Object?>[]);
      await repository.getTasks(const TaskQuery());
      final query = net.adapter.callsTo('/v1/tasks').single.uri.queryParameters;
      expect(query.keys, unorderedEquals(<String>['page', 'pageSize', 'sort']));
    });

    test('returns entities and paging information and saves them', () async {
      stubList(<Object?>[taskJson(), taskJson(id: 't2')], total: 5);

      final loaded = await repository.getTasks(const TaskQuery(pageSize: 2));

      expect(loaded.isStale, isFalse);
      expect(loaded.fetchedAt, fixedNow);
      expect(loaded.data.items.map((t) => t.id), <String>['t1', 't2']);
      expect(loaded.data.total, 5);
      expect(await net.taskLocal.find('t2'), isNotNull);
    });

    test(
      'a malformed response becomes ParsingFailure and is not masked',
      () async {
        await net.taskLocal.saveRemote([
          TaskModelFixtures.task('t1'),
        ], fixedNow);
        net.adapter.onGet(
          TestNetwork.path('tasks'),
          (call) => fnp.MockResponse.json(<String, Object?>{'items': 'nope'}),
        );
        await expectLater(
          repository.getTasks(const TaskQuery()),
          throwsA(isA<ParsingFailure>()),
        );
      },
    );

    test('a forbidden response is not masked by saved data', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onGet(
        TestNetwork.path('tasks'),
        (call) =>
            fnp.MockResponse.json(errorJson('forbidden'), statusCode: 403),
      );
      await expectLater(
        repository.getTasks(const TaskQuery()),
        throwsA(isA<ForbiddenFailure>()),
      );
    });
  });

  group('getTasks offline', () {
    test('answers from the database and flags the result stale', () async {
      var reachable = true;
      net.adapter.onGet(
        TestNetwork.path('tasks'),
        (call) => reachable
            ? fnp.MockResponse.json(
                pageJson(<Object?>[
                  taskJson(),
                  taskJson(id: 't2', title: 'Ship it', status: 'done'),
                ]),
              )
            : unreachable(),
      );
      await repository.getTasks(const TaskQuery());
      reachable = false;

      final stale = await repository.getTasks(const TaskQuery());
      expect(stale.isStale, isTrue);
      expect(stale.fetchedAt, fixedNow);
      expect(stale.data.items, hasLength(2));

      final done = await repository.getTasks(
        const TaskQuery(statuses: {TaskStatus.done}),
      );
      expect(done.data.items.map((t) => t.id), <String>['t2']);
      final searched = await repository.getTasks(
        const TaskQuery(search: 'ship'),
      );
      expect(searched.data.items.map((t) => t.id), <String>['t2']);
    });

    test('also falls back on server errors', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onGet(
        TestNetwork.path('tasks'),
        (call) =>
            fnp.MockResponse.json(errorJson('server_error'), statusCode: 500),
      );
      final loaded = await repository.getTasks(const TaskQuery());
      expect(loaded.isStale, isTrue);
      expect(loaded.data.items.single.id, 't1');
    });

    test('fails when unreachable and nothing was ever saved', () async {
      net.adapter.onGet(TestNetwork.path('tasks'), (call) => unreachable());
      await expectLater(
        repository.getTasks(const TaskQuery()),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('an empty but known database is a valid stale answer', () async {
      var reachable = true;
      net.adapter.onGet(
        TestNetwork.path('tasks'),
        (call) => reachable
            ? fnp.MockResponse.json(pageJson(<Object?>[taskJson()]))
            : unreachable(),
      );
      await repository.getTasks(const TaskQuery());
      reachable = false;

      final loaded = await repository.getTasks(
        const TaskQuery(search: 'nothing matches this'),
      );
      expect(loaded.isStale, isTrue);
      expect(loaded.data.items, isEmpty);
    });
  });

  group('unsent changes in lists', () {
    test(
      'a task created offline is listed first, even when online again',
      () async {
        stubList(<Object?>[taskJson()]);
        net.connectivity.online = false;
        await repository.createTask(request);
        net.connectivity.online = true;
        // Keep the queue from replaying so the overlay is what is under test.
        net.adapter.onPost(TestNetwork.path('tasks'), (call) => unreachable());

        final loaded = await repository.getTasks(const TaskQuery());

        expect(loaded.data.items.map((t) => t.id), <String>[
          'local-id-1',
          't1',
        ]);
        expect(loaded.data.items.first.syncState, SyncState.pending);
        expect(loaded.data.total, 2);
      },
    );

    test('created tasks are only added to the first page', () async {
      stubList(<Object?>[taskJson()]);
      net.connectivity.online = false;
      await repository.createTask(request);
      net.connectivity.online = true;

      final second = await repository.getTasks(const TaskQuery(page: 2));

      expect(second.data.items.map((t) => t.id), <String>['t1']);
    });

    test('an unsent edit replaces the server version', () async {
      stubList(<Object?>[taskJson()]);
      await repository.getTasks(const TaskQuery());
      net.connectivity.online = false;
      await repository.updateTask(
        't1',
        const UpdateTaskRequest(title: 'Edited offline'),
      );
      net.connectivity.online = true;

      final loaded = await repository.getTasks(const TaskQuery());

      expect(loaded.data.items.single.title, 'Edited offline');
      expect(loaded.data.items.single.syncState, SyncState.pending);
    });

    test('a task being deleted disappears from the list', () async {
      stubList(<Object?>[taskJson(), taskJson(id: 't2')], total: 2);
      await repository.getTasks(const TaskQuery());
      net.connectivity.online = false;
      await repository.deleteTask('t1');
      net.connectivity.online = true;

      final loaded = await repository.getTasks(const TaskQuery());

      expect(loaded.data.items.map((t) => t.id), <String>['t2']);
      expect(loaded.data.total, 1);
    });
  });

  group('getTask', () {
    test('loads from the server and saves a copy', () async {
      net.adapter.onGet(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.json(taskJson()),
      );
      final loaded = await repository.getTask('t1');
      expect(loaded.isStale, isFalse);
      expect(loaded.data.attachments, hasLength(1));
      expect(await net.taskLocal.find('t1'), isNotNull);
    });

    test('404 becomes NotFoundFailure', () async {
      net.adapter.onGet(
        TestNetwork.path('tasks/missing'),
        (call) =>
            fnp.MockResponse.json(errorJson('not_found'), statusCode: 404),
      );
      await expectLater(
        repository.getTask('missing'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('falls back to the saved copy when unreachable', () async {
      var reachable = true;
      net.adapter.onGet(
        TestNetwork.path('tasks/t1'),
        (call) => reachable ? fnp.MockResponse.json(taskJson()) : unreachable(),
      );
      await repository.getTask('t1');
      reachable = false;

      final loaded = await repository.getTask('t1');

      expect(loaded.isStale, isTrue);
      expect(loaded.data.title, 'Write spec');
    });

    test('fails when unreachable and never saved', () async {
      net.adapter.onGet(TestNetwork.path('tasks/t1'), (call) => unreachable());
      await expectLater(
        repository.getTask('t1'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('returns an unsent edit without asking the server', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.connectivity.online = false;
      await repository.updateTask(
        't1',
        const UpdateTaskRequest(status: TaskStatus.done),
      );

      final loaded = await repository.getTask('t1');

      expect(loaded.data.status, TaskStatus.done);
      expect(loaded.data.syncState, SyncState.pending);
      expect(net.adapter.callsTo('/v1/tasks/t1'), isEmpty);
    });

    test('a task created on this device is read locally', () async {
      net.connectivity.online = false;
      final created = await repository.createTask(request);

      final loaded = await repository.getTask(created.id);

      expect(loaded.data.id, created.id);
      expect(net.adapter.capturedRequests, isEmpty);
    });

    test('an unknown local id is not found', () async {
      await expectLater(
        repository.getTask('local-nope'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('a task being deleted is not found', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.connectivity.online = false;
      await repository.deleteTask('t1');
      await expectLater(
        repository.getTask('t1'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('createTask', () {
    test(
      'online: posts with an idempotency key and stores the server task',
      () async {
        net.adapter.onPost(
          TestNetwork.path('tasks'),
          (call) =>
              fnp.MockResponse.json(taskJson(id: 'srv-1'), statusCode: 201),
        );

        final task = await repository.createTask(request);

        expect(task.id, 'srv-1');
        expect(task.syncState, SyncState.synced);
        final call = net.adapter.callsTo('/v1/tasks').single;
        expect(header(call, 'Idempotency-Key'), 'id-1');
        expect(call.bodyJson, containsPair('title', 'Write spec'));
        expect(call.bodyJson, containsPair('priority', 'high'));
        expect(await net.taskLocal.find('srv-1'), isNotNull);
        expect(await net.taskLocal.find('local-id-1'), isNull);
        expect(await net.taskLocal.contains('id-1'), isFalse);
      },
    );

    test('a rejected create leaves nothing behind', () async {
      net.adapter.onPost(
        TestNetwork.path('tasks'),
        (call) => fnp.MockResponse.json(
          errorJson(
            'validation_failed',
            fields: <String, String>{'title': 'Required'},
          ),
          statusCode: 422,
        ),
      );

      await expectLater(
        repository.createTask(request),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors['title'],
            'title',
            'Required',
          ),
        ),
      );

      expect(await net.taskLocal.hasData(), isFalse);
      expect(await net.taskLocal.contains('id-1'), isFalse);
    });

    test(
      'offline: kept locally as pending, delivered after reconnecting',
      () async {
        net.adapter.onPost(
          TestNetwork.path('tasks'),
          (call) =>
              fnp.MockResponse.json(taskJson(id: 'srv-1'), statusCode: 201),
        );
        net.connectivity.online = false;

        final task = await repository.createTask(request);

        expect(task.id, 'local-id-1');
        expect(task.syncState, SyncState.pending);
        expect(task.createdAt, fixedNow);
        expect(net.client.offlineQueue!.pending, 1);
        expect(net.adapter.callsTo('/v1/tasks'), isEmpty);
        expect(await listedIds(), <String>['local-id-1']);

        net.connectivity.online = true;
        await net.settleQueue();

        final posts = net.adapter
            .callsTo('/v1/tasks')
            .where((c) => c.method == fnp.HttpMethod.post);
        expect(posts, hasLength(1));
        expect(await net.taskLocal.find('local-id-1'), isNull);
        final synced = (await net.taskLocal.find('srv-1'))!;
        expect(synced.syncState, SyncState.synced);
        expect(await net.taskLocal.contains('id-1'), isFalse);
      },
    );

    test(
      'a create the server rejects on replay stays visible as failed',
      () async {
        net.adapter.onPost(
          TestNetwork.path('tasks'),
          (call) => fnp.MockResponse.json(
            errorJson('validation_failed'),
            statusCode: 422,
          ),
        );
        net.connectivity.online = false;
        await repository.createTask(request);

        net.connectivity.online = true;
        await net.settleQueue();

        final record = (await net.taskLocal.find('local-id-1'))!;
        expect(record.syncState, SyncState.failed);
        expect(await net.taskLocal.contains('id-1'), isFalse);
        expect(await listedIds(), <String>['local-id-1']);
      },
    );
  });

  group('updateTask', () {
    test('online: patches and stores the server version', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onPatch(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.json(taskJson(status: 'done')),
      );

      final task = await repository.updateTask(
        't1',
        const UpdateTaskRequest(status: TaskStatus.done),
      );

      expect(task.status, TaskStatus.done);
      expect(task.syncState, SyncState.synced);
      expect((await net.taskLocal.find('t1'))!.syncState, SyncState.synced);
      expect(
        header(net.adapter.callsTo('/v1/tasks/t1').single, 'Idempotency-Key'),
        'id-1',
      );
    });

    test('loads the task first when no copy is saved', () async {
      net.adapter
        ..onGet(
          TestNetwork.path('tasks/t1'),
          (call) => fnp.MockResponse.json(taskJson()),
        )
        ..onPatch(
          TestNetwork.path('tasks/t1'),
          (call) => fnp.MockResponse.json(taskJson(status: 'done')),
        );

      await repository.updateTask(
        't1',
        const UpdateTaskRequest(status: TaskStatus.done),
      );

      final methods = net.adapter.capturedRequests.map((c) => c.method.value);
      expect(methods, <String>['GET', 'PATCH']);
    });

    test('offline: applies the change locally and sends it later', () async {
      await net.taskLocal.saveRemote([
        TaskModelFixtures.task('t1', dueDate: DateTime.utc(2026, 10, 5)),
      ], fixedNow);
      net.adapter.onPatch(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.json(taskJson(status: 'done')),
      );
      net.connectivity.online = false;

      final task = await repository.updateTask(
        't1',
        const UpdateTaskRequest(status: TaskStatus.done, clearDueDate: true),
      );

      expect(task.status, TaskStatus.done);
      expect(task.dueDate, isNull);
      expect(task.title, 'Write spec');
      expect(task.syncState, SyncState.pending);
      expect(net.client.offlineQueue!.pending, 1);

      net.connectivity.online = true;
      await net.settleQueue();

      final patch = net.adapter.callsTo('/v1/tasks/t1').single;
      expect(patch.bodyJson, <String, Object?>{
        'status': 'done',
        'dueDate': null,
      });
      expect((await net.taskLocal.find('t1'))!.syncState, SyncState.synced);
    });

    test('offline without a saved copy fails and queues nothing', () async {
      net.adapter.onGet(TestNetwork.path('tasks/t1'), (call) => unreachable());
      await expectLater(
        repository.updateTask(
          't1',
          const UpdateTaskRequest(status: TaskStatus.done),
        ),
        throwsA(isA<NetworkFailure>()),
      );
      expect(net.client.offlineQueue!.pending, 0);
    });

    test('a rejected update restores the previous version', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onPatch(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.json(
          errorJson(
            'validation_failed',
            fields: <String, String>{'title': 'Too long'},
          ),
          statusCode: 422,
        ),
      );

      await expectLater(
        repository.updateTask('t1', const UpdateTaskRequest(title: 'x')),
        throwsA(isA<ValidationFailure>()),
      );

      final record = (await net.taskLocal.find('t1'))!;
      expect(record.model.title, 'Write spec');
      expect(record.syncState, SyncState.synced);
      expect(await net.taskLocal.contains('id-1'), isFalse);
    });

    test(
      'a task that only exists on this device cannot be edited yet',
      () async {
        net.connectivity.online = false;
        final created = await repository.createTask(request);

        await expectLater(
          repository.updateTask(
            created.id,
            const UpdateTaskRequest(title: 'Changed'),
          ),
          throwsA(
            isA<OfflineFailure>().having(
              (f) => f.message,
              'message',
              AppStrings.taskPendingSync,
            ),
          ),
        );
      },
    );
  });

  group('deleteTask', () {
    test('online: deletes on the server and locally', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onDelete(TestNetwork.path('tasks/t1'), (call) => noContent());

      await repository.deleteTask('t1');

      expect(net.adapter.callsTo('/v1/tasks/t1'), hasLength(1));
      expect(await net.taskLocal.find('t1'), isNull);
      expect(net.client.offlineQueue!.pending, 0);
    });

    test('offline: hidden at once and sent after reconnecting', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onDelete(TestNetwork.path('tasks/t1'), (call) => noContent());
      net.connectivity.online = false;

      await repository.deleteTask('t1');

      expect(await listedIds(), isEmpty);
      expect(net.adapter.callsTo('/v1/tasks/t1'), isEmpty);
      expect(net.client.offlineQueue!.pending, 1);

      net.connectivity.online = true;
      await net.settleQueue();

      expect(net.adapter.callsTo('/v1/tasks/t1'), hasLength(1));
      expect(await net.taskLocal.find('t1'), isNull);
    });

    test('a task already gone on the server counts as deleted', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onDelete(
        TestNetwork.path('tasks/t1'),
        (call) =>
            fnp.MockResponse.json(errorJson('not_found'), statusCode: 404),
      );

      await repository.deleteTask('t1');

      expect(await net.taskLocal.find('t1'), isNull);
    });

    test('a refused deletion brings the task back', () async {
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.adapter.onDelete(
        TestNetwork.path('tasks/t1'),
        (call) =>
            fnp.MockResponse.json(errorJson('forbidden'), statusCode: 403),
      );

      await expectLater(
        repository.deleteTask('t1'),
        throwsA(isA<ForbiddenFailure>()),
      );

      expect(await listedIds(), <String>['t1']);
      expect((await net.taskLocal.find('t1'))!.syncState, SyncState.synced);
      expect(await net.taskLocal.pendingDeleteIds(), isEmpty);
    });

    test(
      'a task that only exists on this device cannot be deleted yet',
      () async {
        net.connectivity.online = false;
        final created = await repository.createTask(request);
        await expectLater(
          repository.deleteTask(created.id),
          throwsA(isA<OfflineFailure>()),
        );
      },
    );
  });

  group('queued requests of a previous session', () {
    test('are never sent after the local data was cleared', () async {
      net.adapter.onPost(
        TestNetwork.path('tasks'),
        (call) => fnp.MockResponse.json(taskJson(id: 'srv-1'), statusCode: 201),
      );
      net.connectivity.online = false;
      await repository.createTask(request);
      expect(net.client.offlineQueue!.pending, 1);

      await net.cleaner.clear(); // what signing out does

      net.connectivity.online = true;
      await net.settleQueue();

      expect(net.adapter.callsTo('/v1/tasks'), isEmpty);
      expect(net.client.offlineQueue!.pending, 0);
      expect(await net.taskLocal.hasData(), isFalse);
    });
  });

  group('SyncRepositoryImpl', () {
    test(
      'reports the queue size only after local data is up to date',
      () async {
        net.adapter.onPost(
          TestNetwork.path('tasks'),
          (call) =>
              fnp.MockResponse.json(taskJson(id: 'srv-1'), statusCode: 201),
        );
        final sync = SyncRepositoryImpl(
          SyncRemoteDataSource(net.client),
          net.syncHandler,
        );
        final seen = <String>[];
        final subscription = sync.pendingChanges.listen((count) async {
          final delivered = await net.taskLocal.find('srv-1');
          seen.add('$count:${delivered == null ? 'missing' : 'present'}');
        });
        net.connectivity.online = false;
        await repository.createTask(request);

        net.connectivity.online = true;
        await net.settleQueue();
        await pumpEventQueue();

        expect(seen.last, '0:present');
        await subscription.cancel();
      },
    );

    test('syncNow sends waiting changes', () async {
      net.adapter.onDelete(TestNetwork.path('tasks/t1'), (call) => noContent());
      await net.taskLocal.saveRemote([TaskModelFixtures.task('t1')], fixedNow);
      net.connectivity.online = false;
      await repository.deleteTask('t1');

      net.connectivity.online = true;
      await SyncRepositoryImpl(
        SyncRemoteDataSource(net.client),
        net.syncHandler,
      ).syncNow();
      await net.settleQueue();

      expect(net.adapter.callsTo('/v1/tasks/t1'), hasLength(1));
    });
  });
}

/// Stored-task builders for tests that need data before the first call.
abstract final class TaskModelFixtures {
  static TaskModel task(String id, {DateTime? dueDate}) => TaskModel.fromJson(
    taskJson(id: id, dueDate: dueDate?.toUtc().toIso8601String()),
  );
}
