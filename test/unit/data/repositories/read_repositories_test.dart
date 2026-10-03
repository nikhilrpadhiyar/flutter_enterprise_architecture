import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/dashboard_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/profile_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/project_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/repositories/dashboard_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/profile_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/project_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/entities/project_query.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_profile_request.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/test_network.dart';

void main() {
  late TestNetwork net;

  setUp(() async {
    net = TestNetwork();
    await net.signIn();
  });

  tearDown(() => net.dispose());

  group('ProjectRepositoryImpl', () {
    late ProjectRepositoryImpl repository;
    setUp(
      () => repository = ProjectRepositoryImpl(
        ProjectRemoteDataSource(net.requester),
        net.logger,
      ),
    );

    test('lists projects with search and paging', () async {
      net.adapter.onGet(
        TestNetwork.path('projects'),
        (call) => fnp.MockResponse.json(
          pageJson(<Object?>[projectJson(), projectJson(id: 'p2')], total: 50),
        ),
      );

      final loaded = await repository.getProjects(
        const ProjectQuery(page: 3, search: 'la'),
      );

      expect(loaded.data.items.map((p) => p.id), <String>['p1', 'p2']);
      expect(loaded.data.hasMore, isTrue);
      expect(
        net.adapter.callsTo('/v1/projects').single.uri.queryParameters,
        <String, String>{'page': '3', 'pageSize': '20', 'q': 'la'},
      );
    });

    test('loads a single project', () async {
      net.adapter.onGet(
        TestNetwork.path('projects/p1'),
        (call) => fnp.MockResponse.json(projectJson()),
      );
      expect((await repository.getProject('p1')).data.name, 'Launch');
    });

    test('marks saved data stale when the server is unreachable', () async {
      var reachable = true;
      net.adapter.onGet(
        TestNetwork.path('projects/p1'),
        (call) => reachable
            ? fnp.MockResponse.json(projectJson())
            : fnp.MockResponse.failure(const fnp.ConnectionException()),
      );
      await repository.getProject('p1');
      reachable = false;
      expect((await repository.getProject('p1')).isStale, isTrue);
    });

    test('403 becomes ForbiddenFailure', () async {
      net.adapter.onGet(
        TestNetwork.path('projects/p9'),
        (call) =>
            fnp.MockResponse.json(errorJson('forbidden'), statusCode: 403),
      );
      await expectLater(
        repository.getProject('p9'),
        throwsA(isA<ForbiddenFailure>()),
      );
    });
  });

  group('DashboardRepositoryImpl', () {
    late DashboardRepositoryImpl repository;
    setUp(
      () => repository = DashboardRepositoryImpl(
        DashboardRemoteDataSource(net.requester),
        net.logger,
      ),
    );

    test('loads the summary', () async {
      net.adapter.onGet(
        TestNetwork.path('dashboard/summary'),
        (call) => fnp.MockResponse.json(dashboardJson()),
      );
      final loaded = await repository.getSummary();
      expect(loaded.data.openTaskCount, 5);
      expect(loaded.data.pendingTasks, hasLength(1));
    });

    test('a 500 becomes ServerFailure', () async {
      net.adapter.onGet(
        TestNetwork.path('dashboard/summary'),
        (call) =>
            fnp.MockResponse.json(errorJson('server_error'), statusCode: 500),
      );
      await expectLater(
        repository.getSummary(),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 500),
        ),
      );
    });
  });

  group('ProfileRepositoryImpl', () {
    late ProfileRepositoryImpl repository;
    setUp(
      () => repository = ProfileRepositoryImpl(
        ProfileRemoteDataSource(net.requester),
        net.sessionLocal,
        net.logger,
      ),
    );

    test('loads the profile', () async {
      net.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.json(userJson()),
      );
      expect((await repository.getProfile()).data.name, 'Ada Lovelace');
    });

    test('patches only the changed fields', () async {
      net.adapter.onPatch(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.json(userJson()..['phone'] = '555'),
      );

      final user = await repository.updateProfile(
        const UpdateProfileRequest(phone: '555'),
      );

      expect(user.phone, '555');
      expect(
        net.adapter.callsTo('/v1/profile').single.bodyJson,
        <String, Object?>{'phone': '555'},
      );
    });
  });
}
