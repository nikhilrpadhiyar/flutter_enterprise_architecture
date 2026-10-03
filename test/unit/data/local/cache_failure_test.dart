import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/local_guard.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/preferences_local_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/session_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/profile_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/sync_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/task_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/models/user_model.dart';
import 'package:flutter_enterprise_architecture/data/repositories/auth_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/profile_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/task_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_profile_request.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/sequential_ids.dart';
import '../../../helpers/task_models.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_network.dart';

/// Makes every query fail, as a full disk or damaged file would.
Future<void> _breakStorage(AppDatabase db) async {
  await db.customStatement('DROP TABLE local_tasks');
  await db.customStatement('DROP TABLE pending_operations');
  await db.customStatement('DROP TABLE key_values');
}

void main() {
  group('guardLocal', () {
    test('returns the result', () async {
      expect(await guardLocal(() async => 3), 3);
    });

    test(
      'turns any other error into a CacheFailure keeping the cause',
      () async {
        final cause = StateError('disk full');
        await expectLater(
          guardLocal<void>(() async => throw cause),
          throwsA(
            isA<CacheFailure>().having((f) => f.cause, 'cause', same(cause)),
          ),
        );
      },
    );

    test('lets app failures through unchanged', () async {
      await expectLater(
        guardLocal<void>(() async => throw const NotFoundFailure()),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('storage that cannot be used', () {
    test('reports a broken database as a CacheFailure', () async {
      final db = createTestDatabase();
      final tasks = TaskLocalDataSourceImpl(db);
      final prefs = PreferencesLocalDataSourceImpl(db);
      await _breakStorage(db);

      await expectLater(tasks.hasData(), throwsA(isA<CacheFailure>()));
      await expectLater(tasks.find('t1'), throwsA(isA<CacheFailure>()));
      await expectLater(
        tasks.query(const TaskQuery()),
        throwsA(isA<CacheFailure>()),
      );
      await expectLater(
        tasks.saveRemote([taskModel()], DateTime.utc(2026)),
        throwsA(isA<CacheFailure>()),
      );
      await expectLater(tasks.clear(), throwsA(isA<CacheFailure>()));
      await expectLater(
        SessionLocalDataSourceImpl(db).readUser(),
        throwsA(isA<CacheFailure>()),
      );
      await expectLater(prefs.read('k'), throwsA(isA<CacheFailure>()));
      await expectLater(prefs.write('k', 'v'), throwsA(isA<CacheFailure>()));
    });

    test('reports a corrupt stored task as a CacheFailure', () async {
      final db = createTestDatabase();
      final tasks = TaskLocalDataSourceImpl(db);
      await tasks.saveRemote([taskModel()], DateTime.utc(2026));
      await db.customStatement("UPDATE local_tasks SET json = 'not json'");

      await expectLater(tasks.find('t1'), throwsA(isA<CacheFailure>()));
      await db.close();
    });
  });

  group('repositories with a broken cache', () {
    late TestNetwork net;
    final now = DateTime.utc(2026, 10, 2, 12);

    setUp(() async {
      net = TestNetwork();
      await net.signIn();
      await _breakStorage(net.database);
    });

    TaskRepositoryImpl tasks() => TaskRepositoryImpl(
      TaskRemoteDataSource(net.requester),
      net.taskLocal,
      net.logger,
      SequentialIds(),
      clock: () => now,
    );

    test('the task list still shows what the server sent', () async {
      net.adapter.onGet(
        TestNetwork.path('tasks'),
        (call) => fnp.MockResponse.json(pageJson(<Object?>[taskJson()])),
      );

      final loaded = await tasks().getTasks(const TaskQuery());

      expect(loaded.data.items.single.id, 't1');
      expect(loaded.isStale, isFalse);
      expect(net.logLines.join(), contains('local storage unavailable'));
    });

    test('a task still opens from the server', () async {
      net.adapter.onGet(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.json(taskJson()),
      );
      expect((await tasks().getTask('t1')).data.id, 't1');
    });

    test(
      'a failed server read with a broken cache shows the real error',
      () async {
        net.adapter.onGet(
          TestNetwork.path('tasks'),
          (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
        );
        await expectLater(
          tasks().getTasks(const TaskQuery()),
          throwsA(isA<NetworkFailure>()),
        );
      },
    );

    test('creating a task reports that it could not be kept', () async {
      await expectLater(
        tasks().createTask(
          const CreateTaskRequest(
            title: 'x',
            projectId: 'p1',
            priority: TaskPriority.low,
          ),
        ),
        throwsA(isA<CacheFailure>()),
      );
      expect(net.adapter.capturedRequests, isEmpty);
    });

    test('signing in still works', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.json(sessionJson()),
      );
      final repository = AuthRepositoryImpl(
        AuthRemoteDataSource(net.requester, net.tokens, clock: () => now),
        net.sessionLocal,
        net.cleaner,
        SyncRemoteDataSource(net.client),
        net.expiry,
        net.logger,
      );

      final user = await repository.login(
        email: 'ada@example.com',
        password: 'Password1',
      );

      expect(user.name, 'Ada Lovelace');
    });

    test('the profile still loads and saves', () async {
      net.adapter
        ..onGet(
          TestNetwork.path('profile'),
          (call) => fnp.MockResponse.json(userJson()),
        )
        ..onPatch(
          TestNetwork.path('profile'),
          (call) => fnp.MockResponse.json(userJson()),
        );
      final repository = ProfileRepositoryImpl(
        ProfileRemoteDataSource(net.requester),
        net.sessionLocal,
        net.logger,
      );

      expect((await repository.getProfile()).data.id, 'u1');
      expect(
        await repository.updateProfile(const UpdateProfileRequest(phone: '1')),
        UserModel.fromJson(userJson()).toEntity(),
      );
    });
  });
}
