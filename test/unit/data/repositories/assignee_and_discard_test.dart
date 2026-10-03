import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/assignee_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/task_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/repositories/assignee_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/task_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/entities/assignee.dart';
import 'package:flutter_enterprise_architecture/domain/entities/loaded.dart';
import 'package:flutter_enterprise_architecture/domain/entities/sync_state.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/assignee_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/task_repository.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/discard_local_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_assignees_use_case.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/sequential_ids.dart';
import '../../../helpers/task_models.dart';
import '../../../helpers/test_network.dart';

class _MockAssigneeRepository extends Mock implements AssigneeRepository {}

void main() {
  late TestNetwork net;
  final now = DateTime.utc(2026, 10, 2, 12);

  setUp(() async {
    net = TestNetwork();
    await net.signIn();
  });
  tearDown(() => net.dispose());

  group('AssigneeRepositoryImpl', () {
    late AssigneeRepositoryImpl repository;

    setUp(
      () => repository = AssigneeRepositoryImpl(
        AssigneeRemoteDataSource(net.requester),
        net.logger,
      ),
    );

    test('loads the people available for assignment', () async {
      net.adapter.onGet(
        TestNetwork.path('users'),
        (call) => fnp.MockResponse.json(
          pageJson(<Object?>[
            <String, Object?>{'id': 'u1', 'name': 'Ada'},
            <String, Object?>{'id': 'u2', 'name': 'Grace'},
          ]),
        ),
      );

      final loaded = await repository.getAssignees();

      expect(loaded.isStale, isFalse);
      expect(loaded.data, const [
        Assignee(id: 'u1', name: 'Ada'),
        Assignee(id: 'u2', name: 'Grace'),
      ]);
      final query = net.adapter.callsTo('/v1/users').single.uri.queryParameters;
      expect(query, <String, String>{'page': '1', 'pageSize': '100'});
    });

    test('uses the response cache and flags it when offline', () async {
      var reachable = true;
      net.adapter.onGet(
        TestNetwork.path('users'),
        (call) => reachable
            ? fnp.MockResponse.json(
                pageJson(<Object?>[
                  <String, Object?>{'id': 'u1', 'name': 'Ada'},
                ]),
              )
            : fnp.MockResponse.failure(const fnp.ConnectionException()),
      );
      await repository.getAssignees();
      reachable = false;

      final loaded = await repository.getAssignees();

      expect(loaded.isStale, isTrue);
      expect(loaded.data.single.name, 'Ada');
    });

    test('fails when unreachable and never loaded', () async {
      net.adapter.onGet(
        TestNetwork.path('users'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );
      await expectLater(
        repository.getAssignees(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('discardLocalChanges', () {
    late TaskRepositoryImpl repository;

    setUp(
      () => repository = TaskRepositoryImpl(
        TaskRemoteDataSource(net.requester),
        net.taskLocal,
        net.logger,
        SequentialIds(),
        clock: () => now,
      ),
    );

    test('forgets a task that only exists on this device', () async {
      await net.taskLocal.beginChange(
        key: 'k1',
        kind: PendingKind.create,
        task: taskModel(id: 'local-k1'),
        now: now,
      );
      await net.taskLocal.failChange('k1');

      await repository.discardLocalChanges('local-k1');

      expect(await net.taskLocal.find('local-k1'), isNull);
      expect(net.adapter.capturedRequests, isEmpty);
    });

    test('restores the server version of a rejected edit', () async {
      await net.taskLocal.saveRemote([taskModel(title: 'Server')], now);
      await net.taskLocal.beginChange(
        key: 'k1',
        kind: PendingKind.update,
        task: taskModel(title: 'Rejected edit'),
        now: now,
      );
      await net.taskLocal.failChange('k1');
      net.adapter.onGet(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.json(taskJson(title: 'Server')),
      );

      await repository.discardLocalChanges('t1');

      final record = (await net.taskLocal.find('t1'))!;
      expect(record.model.title, 'Server');
      expect(record.syncState, SyncState.synced);
    });

    test('still succeeds when the server cannot be reached', () async {
      await net.taskLocal.saveRemote([taskModel()], now);
      net.adapter.onGet(
        TestNetwork.path('tasks/t1'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );

      await repository.discardLocalChanges('t1');

      expect(await net.taskLocal.find('t1'), isNull);
    });
  });

  group('use cases', () {
    test('GetAssigneesUseCase returns the repository result', () async {
      final repository = _MockAssigneeRepository();
      const loaded = Loaded(<Assignee>[Assignee(id: 'u1', name: 'Ada')]);
      when(repository.getAssignees).thenAnswer((_) async => loaded);

      expect(await GetAssigneesUseCase(repository)(), loaded);
    });

    test('DiscardLocalChangesUseCase rejects a blank id', () async {
      final repository = MockTaskRepository();
      await expectLater(
        DiscardLocalChangesUseCase(repository)(' '),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNever(() => repository.discardLocalChanges(any()));
    });

    test('DiscardLocalChangesUseCase discards by id', () async {
      final TaskRepository repository = MockTaskRepository();
      when(() => repository.discardLocalChanges('t1')).thenAnswer((_) async {});
      await DiscardLocalChangesUseCase(repository)('t1');
      verify(() => repository.discardLocalChanges('t1')).called(1);
    });
  });
}
