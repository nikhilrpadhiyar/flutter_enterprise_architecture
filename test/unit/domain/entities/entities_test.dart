import 'package:flutter_enterprise_architecture/core/constants/app_limits.dart';
import 'package:flutter_enterprise_architecture/domain/entities/paged_result.dart';
import 'package:flutter_enterprise_architecture/domain/entities/sync_state.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_sort.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_task_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/domain_fixtures.dart';

void main() {
  group('Task', () {
    test('is overdue only when past due and not done', () {
      final past = fixtureNow.subtract(const Duration(days: 1));
      final future = fixtureNow.add(const Duration(days: 1));
      expect(buildTask(dueDate: past).isOverdue(fixtureNow), isTrue);
      expect(buildTask(dueDate: future).isOverdue(fixtureNow), isFalse);
      expect(buildTask().isOverdue(fixtureNow), isFalse);
      expect(
        buildTask(status: TaskStatus.done, dueDate: past).isOverdue(fixtureNow),
        isFalse,
      );
    });

    test('copyWith changes only the given fields', () {
      final task = buildTask();
      final changed = task.copyWith(
        status: TaskStatus.done,
        syncState: SyncState.pending,
      );
      expect(changed.id, task.id);
      expect(changed.title, task.title);
      expect(changed.status, TaskStatus.done);
      expect(changed.syncState, SyncState.pending);
      expect(task.syncState, SyncState.synced);
    });

    test('has value equality', () {
      expect(buildTask(), buildTask());
      expect(buildTask(), isNot(buildTask(id: 't2')));
    });
  });

  group('Project.progress', () {
    test('is the completed share of tasks', () {
      expect(buildProject().progress, 0.4);
    });

    test('is zero when there are no tasks', () {
      expect(buildProject(taskCount: 0, completedCount: 0).progress, 0);
    });
  });

  group('PagedResult.hasMore', () {
    test('is true until the last item is reached', () {
      const first = PagedResult<int>(
        items: <int>[1, 2],
        page: 1,
        pageSize: 2,
        total: 5,
      );
      const last = PagedResult<int>(
        items: <int>[5],
        page: 3,
        pageSize: 2,
        total: 5,
      );
      expect(first.hasMore, isTrue);
      expect(last.hasMore, isFalse);
      expect(const PagedResult<int>.empty().hasMore, isFalse);
    });
  });

  group('TaskQuery', () {
    test('defaults to an unfiltered first page', () {
      const query = TaskQuery();
      expect(query.page, 1);
      expect(query.pageSize, AppLimits.defaultPageSize);
      expect(query.hasFilters, isFalse);
      expect(query.sort, TaskSort.dueDateAscending);
    });

    test('reports filters', () {
      expect(const TaskQuery(search: ' x ').hasFilters, isTrue);
      expect(const TaskQuery(statuses: {TaskStatus.todo}).hasFilters, isTrue);
      expect(
        const TaskQuery(priorities: {TaskPriority.high}).hasFilters,
        isTrue,
      );
      expect(const TaskQuery(projectId: 'p1').hasFilters, isTrue);
      expect(const TaskQuery(search: '  ').hasFilters, isFalse);
    });

    test('pages forward and restarts', () {
      const query = TaskQuery(page: 2, search: 'a');
      expect(query.nextPage().page, 3);
      expect(query.nextPage().search, 'a');
      expect(query.firstPage().page, 1);
    });

    test('has value equality including sets', () {
      expect(
        const TaskQuery(statuses: {TaskStatus.todo}),
        const TaskQuery(statuses: {TaskStatus.todo}),
      );
    });
  });

  group('UpdateTaskRequest.isEmpty', () {
    test('is true only when nothing changes', () {
      expect(const UpdateTaskRequest().isEmpty, isTrue);
      expect(const UpdateTaskRequest(title: 'x').isEmpty, isFalse);
      expect(const UpdateTaskRequest(clearDueDate: true).isEmpty, isFalse);
    });
  });
}
