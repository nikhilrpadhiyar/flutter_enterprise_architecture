import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/models/task_model.dart';
import 'package:flutter_enterprise_architecture/domain/entities/sync_state.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_sort.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/task_models.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TaskLocalDataSourceImpl local;
  final now = DateTime.utc(2026, 10, 2, 12);

  setUp(() {
    db = createTestDatabase();
    local = TaskLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  Future<List<String>> ids(TaskQuery query, {bool pendingOnly = false}) async {
    final page = await local.query(query, pendingOnly: pendingOnly);
    return page.records.map((r) => r.model.id).toList();
  }

  group('saving and reading', () {
    test('is empty at first', () async {
      expect(await local.hasData(), isFalse);
      expect((await local.query(const TaskQuery())).total, 0);
    });

    test(
      'round trips every field including attachments and activity',
      () async {
        final original = TaskModel.fromJson(
          taskJson(dueDate: '2026-10-05T00:00:00.000Z'),
        );
        await local.saveRemote([original], now);

        final record = (await local.find('t1'))!;
        final entity = record.model.toEntity();
        expect(entity, original.toEntity());
        expect(entity.attachments, hasLength(1));
        expect(entity.activity, hasLength(2));
        expect(record.syncState, SyncState.synced);
        expect(record.cachedAt, now);
        expect(await local.hasData(), isTrue);
      },
    );

    test('saving again updates the existing row', () async {
      await local.saveRemote([taskModel(title: 'Old')], now);
      await local.saveRemote([taskModel(title: 'New')], now);
      final page = await local.query(const TaskQuery());
      expect(page.total, 1);
      expect(page.records.single.model.title, 'New');
    });

    test('saving nothing is a no-op', () async {
      await local.saveRemote(const <TaskModel>[], now);
      expect(await local.hasData(), isFalse);
    });

    test('returns null for an unknown id', () async {
      expect(await local.find('missing'), isNull);
    });
  });

  group('filtering', () {
    setUp(() async {
      await local.saveRemote([
        taskModel(id: 'a', title: 'Fix login bug', priority: TaskPriority.high),
        taskModel(
          id: 'b',
          title: 'Write docs',
          description: 'Mentions LOGIN flow',
          status: TaskStatus.inProgress,
          priority: TaskPriority.low,
          projectId: 'p2',
        ),
        taskModel(
          id: 'c',
          title: '100% done',
          status: TaskStatus.done,
          priority: TaskPriority.urgent,
        ),
      ], now);
    });

    test('by status', () async {
      expect(await ids(const TaskQuery(statuses: {TaskStatus.done})), ['c']);
      expect(
        (await ids(
          const TaskQuery(statuses: {TaskStatus.todo, TaskStatus.inProgress}),
        ))..sort(),
        ['a', 'b'],
      );
    });

    test('by priority', () async {
      expect(
        (await ids(
          const TaskQuery(priorities: {TaskPriority.high, TaskPriority.urgent}),
        ))..sort(),
        ['a', 'c'],
      );
    });

    test('by project', () async {
      expect(await ids(const TaskQuery(projectId: 'p2')), ['b']);
    });

    test('searches titles and descriptions ignoring case', () async {
      expect((await ids(const TaskQuery(search: 'login')))..sort(), ['a', 'b']);
    });

    test('treats percent signs in the search text literally', () async {
      expect(await ids(const TaskQuery(search: '100%')), ['c']);
      expect(await ids(const TaskQuery(search: '%')), ['c']);
      expect(await ids(const TaskQuery(search: 'Write_docs')), isEmpty);
      expect(await ids(const TaskQuery(search: r'\')), isEmpty);
    });

    test('combines filters', () async {
      expect(
        await ids(
          const TaskQuery(
            search: 'login',
            statuses: {TaskStatus.inProgress},
            projectId: 'p2',
          ),
        ),
        ['b'],
      );
      expect(
        await ids(
          const TaskQuery(search: 'login', statuses: {TaskStatus.done}),
        ),
        isEmpty,
      );
    });
  });

  group('sorting and paging', () {
    setUp(() async {
      await local.saveRemote([
        taskModel(
          id: 'a',
          dueDate: DateTime.utc(2026, 10, 9),
          priority: TaskPriority.low,
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
        taskModel(
          id: 'b',
          dueDate: DateTime.utc(2026, 10, 3),
          priority: TaskPriority.urgent,
          updatedAt: DateTime.utc(2026, 10, 2),
        ),
        taskModel(
          id: 'c',
          priority: TaskPriority.high,
          updatedAt: DateTime.utc(2026, 10, 3),
        ),
        taskModel(
          id: 'd',
          dueDate: DateTime.utc(2026, 10, 6),
          priority: TaskPriority.high,
          updatedAt: DateTime.utc(2026, 10, 4),
        ),
      ], now);
    });

    test('by due date ascending puts tasks without a deadline last', () async {
      expect(await ids(const TaskQuery()), ['b', 'd', 'a', 'c']);
    });

    test('by due date descending also puts them last', () async {
      expect(await ids(const TaskQuery(sort: TaskSort.dueDateDescending)), [
        'a',
        'd',
        'b',
        'c',
      ]);
    });

    test('by priority then most recent', () async {
      expect(await ids(const TaskQuery(sort: TaskSort.priority)), [
        'b',
        'd',
        'c',
        'a',
      ]);
    });

    test('by recently updated', () async {
      expect(await ids(const TaskQuery(sort: TaskSort.recentlyUpdated)), [
        'd',
        'c',
        'b',
        'a',
      ]);
    });

    test('pages through results with a correct total', () async {
      const first = TaskQuery(pageSize: 3);
      final page1 = await local.query(first);
      final page2 = await local.query(first.nextPage());
      expect(page1.total, 4);
      expect(page1.records, hasLength(3));
      expect(page2.records, hasLength(1));
      expect([...page1.records, ...page2.records].map((r) => r.model.id), [
        'b',
        'd',
        'a',
        'c',
      ]);
    });

    test('a page past the end is empty', () async {
      final page = await local.query(const TaskQuery(page: 9));
      expect(page.records, isEmpty);
      expect(page.total, 4);
    });

    test('reports when the page was last written', () async {
      final page = await local.query(const TaskQuery());
      expect(page.fetchedAt, now);
      expect(
        (await local.query(const TaskQuery(search: 'zzz'))).fetchedAt,
        isNull,
      );
    });
  });

  group('local changes', () {
    test('a created task is pending, visible and recorded', () async {
      final task = taskModel(id: 'local-k1', title: 'Offline');
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.create,
        task: task,
        now: now,
      );

      final record = (await local.find('local-k1'))!;
      expect(record.syncState, SyncState.pending);
      expect(await local.contains('k1'), isTrue);
      expect((await local.operation('k1'))?.kind, PendingKind.create);
      expect(await ids(const TaskQuery()), ['local-k1']);
      expect(await ids(const TaskQuery(), pendingOnly: true), ['local-k1']);
    });

    test('pending-only ignores synced tasks and paging', () async {
      await local.saveRemote([
        for (var i = 0; i < 5; i++) taskModel(id: 's$i'),
      ], now);
      for (var i = 0; i < 3; i++) {
        await local.beginChange(
          key: 'k$i',
          kind: PendingKind.create,
          task: taskModel(id: 'local-$i'),
          now: now,
        );
      }
      final pending = await local.query(
        const TaskQuery(pageSize: 2),
        pendingOnly: true,
      );
      expect(pending.records, hasLength(3));
      expect(pending.total, 3);
    });

    test('saving server data never overwrites a pending edit', () async {
      await local.saveRemote([taskModel(title: 'Server v1')], now);
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.update,
        task: taskModel(title: 'My edit'),
        now: now,
      );

      await local.saveRemote([taskModel(title: 'Server v2')], now);

      expect((await local.find('t1'))!.model.title, 'My edit');
    });

    test(
      'completing a create swaps the local task for the server version',
      () async {
        await local.beginChange(
          key: 'k1',
          kind: PendingKind.create,
          task: taskModel(id: 'local-k1'),
          now: now,
        );

        await local.completeChange(
          'k1',
          serverTask: taskModel(id: 'srv-9'),
          now: now,
        );

        expect(await local.find('local-k1'), isNull);
        expect((await local.find('srv-9'))!.syncState, SyncState.synced);
        expect(await local.contains('k1'), isFalse);
      },
    );

    test('completing an update stores the server version as synced', () async {
      await local.saveRemote([taskModel(title: 'Old')], now);
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.update,
        task: taskModel(title: 'Edit'),
        now: now,
      );

      await local.completeChange(
        'k1',
        serverTask: taskModel(title: 'Edit (server)'),
        now: now,
      );

      final record = (await local.find('t1'))!;
      expect(record.model.title, 'Edit (server)');
      expect(record.syncState, SyncState.synced);
    });

    test('a pending deletion hides the task until it completes', () async {
      await local.saveRemote([taskModel()], now);

      await local.beginDelete(key: 'k1', taskId: 't1');

      expect(await ids(const TaskQuery()), isEmpty);
      expect(await local.pendingDeleteIds(), {'t1'});
      expect(await local.find('t1'), isNotNull);

      await local.completeChange('k1', now: now);
      expect(await local.find('t1'), isNull);
      expect(await local.pendingDeleteIds(), isEmpty);
    });

    test('a rejected create stays visible and flagged as failed', () async {
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.create,
        task: taskModel(id: 'local-k1'),
        now: now,
      );

      await local.failChange('k1');

      expect((await local.find('local-k1'))!.syncState, SyncState.failed);
      expect(await local.contains('k1'), isFalse);
      expect(await ids(const TaskQuery()), ['local-k1']);
      expect(await ids(const TaskQuery(), pendingOnly: true), ['local-k1']);
    });

    test('a rejected delete brings the task back as failed', () async {
      await local.saveRemote([taskModel()], now);
      await local.beginDelete(key: 'k1', taskId: 't1');

      await local.failChange('k1');

      expect(await ids(const TaskQuery()), ['t1']);
      expect((await local.find('t1'))!.syncState, SyncState.failed);
    });

    test('rolling back restores the previous version', () async {
      await local.saveRemote([taskModel(title: 'Original')], now);
      final previous = (await local.find('t1'))!;
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.update,
        task: taskModel(title: 'Edit'),
        now: now,
      );

      await local.rollbackChange('k1', previous: previous);

      final record = (await local.find('t1'))!;
      expect(record.model.title, 'Original');
      expect(record.syncState, SyncState.synced);
      expect(await local.contains('k1'), isFalse);
    });

    test('rolling back a create removes the task', () async {
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.create,
        task: taskModel(id: 'local-k1'),
        now: now,
      );
      await local.rollbackChange('k1');
      expect(await local.find('local-k1'), isNull);
      expect(await local.contains('k1'), isFalse);
    });

    test('operations on an unknown key do nothing', () async {
      await local.completeChange('nope', now: now);
      await local.failChange('nope');
      await local.rollbackChange('nope');
      expect(await local.hasData(), isFalse);
    });

    test('clear removes tasks and recorded changes', () async {
      await local.saveRemote([taskModel()], now);
      await local.beginChange(
        key: 'k1',
        kind: PendingKind.create,
        task: taskModel(id: 'local-k1'),
        now: now,
      );

      await local.clear();

      expect(await local.hasData(), isFalse);
      expect(await local.contains('k1'), isFalse);
    });
  });
}
