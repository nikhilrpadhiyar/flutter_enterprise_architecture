import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_enterprise_architecture/core/config/app_config.dart';
import 'package:flutter_enterprise_architecture/core/config/app_environment.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/session/session_expiry_notifier.dart';
import 'package:flutter_enterprise_architecture/di/get_di.dart';
import 'package:flutter_enterprise_architecture/domain/entities/project_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/sync_state.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_sort.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/register_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_profile_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/create_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/delete_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_dashboard_summary_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_profile_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_projects_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_tasks_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/login_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/logout_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_pending_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/register_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/restore_session_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/update_profile_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/update_task_use_case.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../tool/mock_server/mock_api_server.dart';
import '../../tool/mock_server/seed_data.dart';
import '../helpers/test_database.dart';

/// Runs the real dependency graph and the real HTTP stack against the mock
/// API server over loopback sockets.
void main() {
  late MockApiServer server;
  late fnp.InMemoryTokenStorage tokens;
  late fnp.FakeConnectivityMonitor connectivity;
  var serverNow = DateTime.now();

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    serverNow = DateTime.now();
    server = MockApiServer(clock: () => serverNow);
    await server.start(port: 0);
    tokens = fnp.InMemoryTokenStorage();
    connectivity = fnp.FakeConnectivityMonitor();
    await GetDI.reset();
    await GetDI.init(
      config: AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: server.baseUrl,
      ),
      overrides: GetDIOverrides(
        logger: ConsoleAppLogger(sink: (_) {}),
        database: createTestDatabase(),
        tokenStorage: tokens,
        cacheStore: fnp.MemoryCacheStore(),
        offlineQueueStore: fnp.InMemoryOfflineQueueStore(),
        connectivity: connectivity,
        retryPolicy: const fnp.RetryPolicy.none(),
      ),
    );
  });

  tearDown(() async {
    await server.stop();
    await GetDI.reset();
  });

  Future<void> signIn() =>
      Get.find<LoginUseCase>()(email: demoEmail, password: demoPassword);

  group('authentication', () {
    test('signs in with the demo account', () async {
      final user = await Get.find<LoginUseCase>()(
        email: demoEmail,
        password: demoPassword,
      );
      expect(user.name, 'Ada Lovelace');
      expect(await tokens.read(), isNotNull);
    });

    test('rejects a wrong password', () async {
      await expectLater(
        Get.find<LoginUseCase>()(email: demoEmail, password: 'Wrong123'),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('registers a new account and rejects a duplicate', () async {
      const request = RegisterRequest(
        name: 'New Person',
        email: 'new@example.com',
        password: 'Secret123',
      );
      final user = await Get.find<RegisterUseCase>()(request);
      expect(user.email, 'new@example.com');

      await expectLater(
        Get.find<RegisterUseCase>()(request),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors.keys,
            'fields',
            contains('email'),
          ),
        ),
      );
    });

    test('restores a saved session and signs out', () async {
      expect(await Get.find<RestoreSessionUseCase>()(), isNull);

      await signIn();
      final restored = await Get.find<RestoreSessionUseCase>()();
      expect(restored?.email, demoEmail);

      await Get.find<LogoutUseCase>()();
      expect(await tokens.read(), isNull);
      expect(await Get.find<RestoreSessionUseCase>()(), isNull);
    });

    test('protected endpoints refuse unauthenticated calls', () async {
      await expectLater(
        Get.find<GetTasksUseCase>()(),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('updates the profile', () async {
      await signIn();
      final user = await Get.find<UpdateProfileUseCase>()(
        const UpdateProfileRequest(name: 'Ada L.', phone: '555-0100'),
      );
      expect(user.name, 'Ada L.');
      final loaded = await Get.find<GetProfileUseCase>()();
      expect(loaded.data.phone, '555-0100');
    });
  });

  group('token refresh', () {
    test(
      'an access token the server rejects is refreshed transparently',
      () async {
        await signIn();
        final before = (await tokens.read())!.accessToken;

        serverNow = serverNow.add(const Duration(hours: 2));
        final page = await Get.find<GetTasksUseCase>()();

        expect(page.data.items, isNotEmpty);
        final after = (await tokens.read())!.accessToken;
        expect(after, isNot(before));
      },
    );

    test('an unusable refresh token ends the session', () async {
      await signIn();
      await tokens.write(
        fnp.AuthTokenPair(
          accessToken: 'stale',
          refreshToken: 'unknown',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final expired = Get.find<SessionExpiryNotifier>().onExpired.first;

      await expectLater(
        Get.find<GetTasksUseCase>()(),
        throwsA(isA<AuthenticationFailure>()),
      );

      await expired.timeout(const Duration(seconds: 2));
      expect(await tokens.read(), isNull);
    });
  });

  group('tasks', () {
    setUp(signIn);

    test('paginates the full task list', () async {
      final first = await Get.find<GetTasksUseCase>()();
      expect(first.data.items, hasLength(20));
      expect(first.data.total, 36);
      expect(first.data.hasMore, isTrue);

      final second = await Get.find<GetTasksUseCase>()(
        const TaskQuery(page: 2),
      );
      expect(second.data.items, hasLength(16));
      expect(second.data.hasMore, isFalse);
    });

    test('filters by status and priority and sorts by priority', () async {
      final loaded = await Get.find<GetTasksUseCase>()(
        const TaskQuery(
          statuses: {TaskStatus.todo, TaskStatus.inProgress},
          priorities: {TaskPriority.high, TaskPriority.urgent},
          sort: TaskSort.priority,
        ),
      );
      final items = loaded.data.items;
      expect(items, isNotEmpty);
      expect(items.every((t) => t.status != TaskStatus.done), isTrue);
      expect(
        items.every(
          (t) =>
              t.priority == TaskPriority.high ||
              t.priority == TaskPriority.urgent,
        ),
        isTrue,
      );
      final ranks = items.map((t) => t.priority.index).toList();
      final descending = List<int>.of(ranks)..sort((a, b) => b.compareTo(a));
      expect(ranks, descending);
    });

    test('searches titles', () async {
      final loaded = await Get.find<GetTasksUseCase>()(
        const TaskQuery(search: 'login timeout'),
      );
      expect(loaded.data.items, isNotEmpty);
      expect(
        loaded.data.items.every(
          (t) => t.title.toLowerCase().contains('login timeout'),
        ),
        isTrue,
      );
    });

    test('loads a task with its attachments and activity', () async {
      final loaded = await Get.find<GetTaskUseCase>()('t1');
      expect(loaded.data.id, 't1');
      expect(loaded.data.activity, isNotEmpty);
      expect(loaded.data.attachments, isNotEmpty);
    });

    test('creates, updates and deletes a task', () async {
      final created = await Get.find<CreateTaskUseCase>()(
        CreateTaskRequest(
          title: '  Integration task ',
          description: 'created by a test',
          projectId: 'p1',
          priority: TaskPriority.urgent,
          assigneeId: 'u2',
          dueDate: DateTime.utc(2030),
        ),
      );
      expect(created.title, 'Integration task');
      expect(created.syncState, SyncState.synced);
      expect(created.assignee?.name, 'Grace Hopper');
      expect(created.dueDate, DateTime.utc(2030));

      final updated = await Get.find<UpdateTaskUseCase>()(
        created.id,
        const UpdateTaskRequest(
          status: TaskStatus.inProgress,
          clearDueDate: true,
        ),
      );
      expect(updated.status, TaskStatus.inProgress);
      expect(updated.dueDate, isNull);
      expect(
        updated.activity.map((a) => a.message),
        contains('moved to inProgress'),
      );

      await Get.find<DeleteTaskUseCase>()(created.id);
      await expectLater(
        Get.find<GetTaskUseCase>()(created.id),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('reports server validation errors', () async {
      await expectLater(
        Get.find<CreateTaskUseCase>()(
          const CreateTaskRequest(
            title: 'Valid title',
            projectId: 'no-such-project',
            priority: TaskPriority.low,
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors['projectId'],
            'projectId',
            'Unknown project',
          ),
        ),
      );
    });
  });

  group('projects and dashboard', () {
    setUp(signIn);

    test('lists projects whose counts add up to the task total', () async {
      final loaded = await Get.find<GetProjectsUseCase>()(const ProjectQuery());
      final projects = loaded.data.items;
      expect(projects, hasLength(3));
      expect(projects.fold<int>(0, (sum, p) => sum + p.taskCount), 36);
    });

    test('summarises the workspace', () async {
      final summary = (await Get.find<GetDashboardSummaryUseCase>()()).data;
      expect(summary.projectCount, 3);
      expect(summary.openTaskCount + summary.completedTaskCount, 36);
      expect(summary.pendingTasks, hasLength(5));
      expect(summary.recentActivity, isNotEmpty);
    });
  });

  group('restart', () {
    test('unsent changes survive closing and reopening the app', () async {
      final directory = Directory.systemTemp.createTempSync('workspace_db');
      final file = File('${directory.path}/app.db');
      final queueStore = fnp.InMemoryOfflineQueueStore();

      Future<void> boot() async {
        await GetDI.reset();
        await GetDI.init(
          config: AppConfig(
            environment: AppEnvironment.development,
            apiBaseUrl: server.baseUrl,
          ),
          overrides: GetDIOverrides(
            logger: ConsoleAppLogger(sink: (_) {}),
            database: AppDatabase(NativeDatabase(file)),
            tokenStorage: tokens,
            cacheStore: fnp.MemoryCacheStore(),
            offlineQueueStore: queueStore,
            connectivity: connectivity,
            retryPolicy: const fnp.RetryPolicy.none(),
          ),
        );
      }

      try {
        await boot();
        await signIn();
        await Get.find<GetTasksUseCase>()();
        connectivity.online = false;
        final created = await Get.find<CreateTaskUseCase>()(
          const CreateTaskRequest(
            title: 'Survives restart',
            projectId: 'p1',
            priority: TaskPriority.high,
          ),
        );
        expect(created.syncState, SyncState.pending);

        await boot(); // the app is closed and opened again

        final listed = await Get.find<GetTasksUseCase>()(
          const TaskQuery(search: 'Survives restart'),
        );
        expect(listed.data.items, hasLength(1));
        expect(listed.data.items.single.syncState, SyncState.pending);

        final drained = Get.find<ObservePendingChangesUseCase>()().firstWhere(
          (count) => count == 0,
        );
        connectivity.online = true;
        await drained.timeout(const Duration(seconds: 10));

        final synced = await Get.find<GetTasksUseCase>()(
          const TaskQuery(search: 'Survives restart'),
        );
        expect(synced.data.items, hasLength(1));
        expect(synced.data.items.single.syncState, SyncState.synced);
        expect(synced.data.items.single.id, isNot(startsWith('local-')));
      } finally {
        await GetDI.reset();
        directory.deleteSync(recursive: true);
      }
    });
  });

  group('offline', () {
    setUp(signIn);

    test('serves saved data when the connection is lost', () async {
      final fresh = await Get.find<GetTasksUseCase>()();
      expect(fresh.isStale, isFalse);

      await server.stop();
      final stale = await Get.find<GetTasksUseCase>()();

      expect(stale.isStale, isTrue);
      // Offline, only what was downloaded is available: the first page.
      expect(
        stale.data.items.map((t) => t.id),
        unorderedEquals(fresh.data.items.map((t) => t.id)),
      );
      expect(stale.data.total, fresh.data.items.length);
      await server.start(port: 0);
    });

    test(
      'a task created offline reaches the server after reconnecting',
      () async {
        connectivity.online = false;
        final pending = await Get.find<CreateTaskUseCase>()(
          const CreateTaskRequest(
            title: 'Created offline',
            projectId: 'p2',
            priority: TaskPriority.medium,
          ),
        );
        expect(pending.syncState, SyncState.pending);

        final drained = Get.find<ObservePendingChangesUseCase>()().firstWhere(
          (count) => count == 0,
        );
        connectivity.online = true;
        await drained.timeout(const Duration(seconds: 10));

        final found = await Get.find<GetTasksUseCase>()(
          const TaskQuery(search: 'Created offline'),
        );
        expect(found.data.items, hasLength(1));
        expect(found.data.items.single.syncState, SyncState.synced);
      },
    );
  });
}
