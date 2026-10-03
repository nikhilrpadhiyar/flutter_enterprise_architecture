import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/domain/entities/dashboard_summary.dart';
import 'package:flutter_enterprise_architecture/domain/entities/loaded.dart';
import 'package:flutter_enterprise_architecture/domain/entities/paged_result.dart';
import 'package:flutter_enterprise_architecture/domain/entities/project.dart';
import 'package:flutter_enterprise_architecture/domain/entities/project_query.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_profile_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_dashboard_summary_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_profile_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_project_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_projects_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_pending_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/sync_pending_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/update_profile_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  setUpAll(() => registerFallbackValue(const UpdateProfileRequest()));

  group('profile', () {
    late MockProfileRepository repository;
    setUp(() => repository = MockProfileRepository());

    test('GetProfileUseCase returns the loaded profile', () async {
      final loaded = Loaded(buildUser());
      when(() => repository.getProfile()).thenAnswer((_) async => loaded);
      expect(await GetProfileUseCase(repository)(), loaded);
    });

    test('UpdateProfileUseCase rejects a blank name', () async {
      await expectLater(
        UpdateProfileUseCase(repository)(const UpdateProfileRequest(name: ' ')),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNever(() => repository.updateProfile(any()));
    });

    test('UpdateProfileUseCase allows phone-only changes and trims', () async {
      when(() => repository.updateProfile(any()))
          .thenAnswer((_) async => buildUser());

      await UpdateProfileUseCase(repository)(
        const UpdateProfileRequest(phone: ' 555 '),
      );

      verify(
        () =>
            repository.updateProfile(const UpdateProfileRequest(phone: '555')),
      ).called(1);
    });
  });

  group('projects', () {
    late MockProjectRepository repository;
    setUp(() => repository = MockProjectRepository());

    test('GetProjectsUseCase passes the query through', () async {
      const query = ProjectQuery(search: 'x');
      const result = Loaded(PagedResult<Project>.empty());
      when(() => repository.getProjects(query)).thenAnswer((_) async => result);
      expect(await GetProjectsUseCase(repository)(query), result);
    });

    test('GetProjectUseCase loads by id', () async {
      final loaded = Loaded(buildProject());
      when(() => repository.getProject('p1')).thenAnswer((_) async => loaded);
      expect(await GetProjectUseCase(repository)('p1'), loaded);
    });
  });

  test('GetDashboardSummaryUseCase returns the summary', () async {
    final repository = MockDashboardRepository();
    const summary = Loaded(
      DashboardSummary(
        projectCount: 1,
        openTaskCount: 2,
        completedTaskCount: 3,
        overdueTaskCount: 0,
        pendingTasks: [],
        completedTasks: [],
        recentActivity: [],
      ),
    );
    when(() => repository.getSummary()).thenAnswer((_) async => summary);
    expect(await GetDashboardSummaryUseCase(repository)(), summary);
  });

  group('sync', () {
    late MockSyncRepository repository;
    setUp(() => repository = MockSyncRepository());

    test('SyncPendingChangesUseCase triggers a sync', () async {
      when(() => repository.syncNow()).thenAnswer((_) async {});
      await SyncPendingChangesUseCase(repository)();
      verify(() => repository.syncNow()).called(1);
    });

    test('ObservePendingChangesUseCase exposes the count stream', () async {
      when(() => repository.pendingChanges)
          .thenAnswer((_) => Stream<int>.fromIterable(<int>[2, 0]));
      expect(await ObservePendingChangesUseCase(repository)().toList(), [2, 0]);
    });
  });
}
