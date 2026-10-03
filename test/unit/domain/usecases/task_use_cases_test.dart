import 'package:flutter_enterprise_architecture/core/constants/app_limits.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/domain/entities/loaded.dart';
import 'package:flutter_enterprise_architecture/domain/entities/paged_result.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/create_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/delete_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_tasks_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/update_task_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockTaskRepository repository;

  setUpAll(() {
    registerFallbackValue(const TaskQuery());
    registerFallbackValue(
      const CreateTaskRequest(
        title: 't',
        projectId: 'p',
        priority: TaskPriority.low,
      ),
    );
    registerFallbackValue(const UpdateTaskRequest());
  });

  setUp(() => repository = MockTaskRepository());

  group('GetTasksUseCase', () {
    test('clamps paging and trims the search text', () async {
      when(() => repository.getTasks(any()))
          .thenAnswer((_) async => const Loaded(PagedResult<Task>.empty()));

      await GetTasksUseCase(repository)(
        const TaskQuery(page: -3, pageSize: 5000, search: '  bug  '),
      );

      final captured =
          verify(() => repository.getTasks(captureAny())).captured.single
              as TaskQuery;
      expect(captured.page, 1);
      expect(captured.pageSize, AppLimits.maxPageSize);
      expect(captured.search, 'bug');
    });

    test('returns stale data from the repository untouched', () async {
      const stale = Loaded(PagedResult<Task>.empty(), isStale: true);
      when(() => repository.getTasks(any())).thenAnswer((_) async => stale);
      expect(await GetTasksUseCase(repository)(), stale);
    });
  });

  test('GetTaskUseCase loads by id', () async {
    final loaded = Loaded(buildTask());
    when(() => repository.getTask('t1')).thenAnswer((_) async => loaded);
    expect(await GetTaskUseCase(repository)('t1'), loaded);
  });

  group('CreateTaskUseCase', () {
    test('rejects a blank title without calling the repository', () async {
      await expectLater(
        CreateTaskUseCase(repository)(
          const CreateTaskRequest(
            title: '   ',
            projectId: 'p1',
            priority: TaskPriority.high,
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors.keys,
            'fields',
            contains('title'),
          ),
        ),
      );
      verifyNever(() => repository.createTask(any()));
    });

    test('requires a project', () async {
      await expectLater(
        CreateTaskUseCase(repository)(
          const CreateTaskRequest(
            title: 'Ok',
            projectId: '',
            priority: TaskPriority.low,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('creates the task with trimmed text', () async {
      final task = buildTask();
      when(() => repository.createTask(any())).thenAnswer((_) async => task);

      final result = await CreateTaskUseCase(repository)(
        const CreateTaskRequest(
          title: '  Write spec ',
          description: ' notes ',
          projectId: 'p1',
          priority: TaskPriority.high,
        ),
      );

      expect(result, task);
      final sent =
          verify(() => repository.createTask(captureAny())).captured.single
              as CreateTaskRequest;
      expect(sent.title, 'Write spec');
      expect(sent.description, 'notes');
    });
  });

  group('UpdateTaskUseCase', () {
    test('rejects an invalid title', () async {
      await expectLater(
        UpdateTaskUseCase(repository)(
          't1',
          const UpdateTaskRequest(title: ' '),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNever(() => repository.updateTask(any(), any()));
    });

    test('rejects an update that changes nothing', () async {
      await expectLater(
        UpdateTaskUseCase(repository)('t1', const UpdateTaskRequest()),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('applies a status change', () async {
      final task = buildTask(status: TaskStatus.done);
      when(() => repository.updateTask('t1', any()))
          .thenAnswer((_) async => task);

      final result = await UpdateTaskUseCase(repository)(
        't1',
        const UpdateTaskRequest(status: TaskStatus.done),
      );

      expect(result.status, TaskStatus.done);
    });
  });

  group('DeleteTaskUseCase', () {
    test('rejects a blank id', () async {
      await expectLater(
        DeleteTaskUseCase(repository)(' '),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNever(() => repository.deleteTask(any()));
    });

    test('deletes by id', () async {
      when(() => repository.deleteTask('t1')).thenAnswer((_) async {});
      await DeleteTaskUseCase(repository)('t1');
      verify(() => repository.deleteTask('t1')).called(1);
    });
  });
}
