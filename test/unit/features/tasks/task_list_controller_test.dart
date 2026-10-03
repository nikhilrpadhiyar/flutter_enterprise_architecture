import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/core/state/view_status.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_durations.dart';
import 'package:flutter_enterprise_architecture/domain/entities/loaded.dart';
import 'package:flutter_enterprise_architecture/domain/entities/paged_result.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_query.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_sort.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/features/tasks/controllers/task_list_controller.dart';
import 'package:flutter_enterprise_architecture/features/tasks/widgets/task_filter_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/console_logger.dart';
import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/mock_use_cases.dart';

void main() {
  late MockGetTasksUseCase getTasks;
  late MockSyncPendingChangesUseCase syncPending;
  late StreamController<int> pending;
  late TaskListController controller;
  late List<String> updates;

  Loaded<PagedResult<Task>> page(
    List<String> ids, {
    int pageNumber = 1,
    int total = 100,
    bool stale = false,
  }) => Loaded(
    PagedResult<Task>(
      items: [for (final id in ids) buildTask(id: id)],
      page: pageNumber,
      pageSize: 20,
      total: total,
    ),
    isStale: stale,
  );

  setUpAll(() => registerFallbackValue(const TaskQuery()));

  setUp(() {
    Get.parameters = <String, String?>{};
    getTasks = MockGetTasksUseCase();
    syncPending = MockSyncPendingChangesUseCase();
    pending = StreamController<int>.broadcast();
    final observe = MockObservePendingChangesUseCase();
    when(observe.call).thenAnswer((_) => pending.stream);
    controller = TaskListController(
      getTasks,
      observe,
      syncPending,
      silentLogger(),
    );
    updates = <String>[];
    for (final id in <String>[
      TaskListController.listId,
      TaskListController.bannerId,
      TaskListController.filtersId,
    ]) {
      controller.addListenerId(id, () => updates.add(id));
    }
  });

  tearDown(() async {
    controller.onClose();
    await pending.close();
  });

  Future<void> start() async {
    controller.onInit();
    await pumpEventQueue();
  }

  test('loads the first page and shows it', () async {
    when(() => getTasks(any())).thenAnswer((_) async => page(['a', 'b']));

    await start();

    expect(controller.status, ViewStatus.success);
    expect(controller.tasks.map((t) => t.id), ['a', 'b']);
    expect(controller.hasMore, isTrue);
    expect(controller.isStale, isFalse);
  });

  test('is empty when nothing comes back', () async {
    when(() => getTasks(any())).thenAnswer((_) async => page([], total: 0));
    await start();
    expect(controller.status, ViewStatus.empty);
    expect(controller.hasFilters, isFalse);
  });

  test('shows an error when the first load fails', () async {
    when(() => getTasks(any())).thenThrow(const NetworkFailure());
    await start();
    expect(controller.status, ViewStatus.error);
    expect(controller.errorMessage, AppStrings.failureNetwork);
  });

  test('keeps the list when a reload fails', () async {
    when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
    await start();

    when(() => getTasks(any())).thenThrow(const TimeoutFailure());
    await controller.reload();

    expect(controller.status, ViewStatus.success);
    expect(controller.tasks, hasLength(1));
    expect(controller.refreshError, AppStrings.failureTimeout);
    expect(controller.errorMessage, isNull);
  });

  test('flags stale data', () async {
    when(() => getTasks(any()))
        .thenAnswer((_) async => page(['a'], stale: true));
    await start();
    expect(controller.isStale, isTrue);
  });

  group('paging', () {
    setUp(() {
      when(() => getTasks(any(that: isA<TaskQuery>()))).thenAnswer((i) async {
        final query = i.positionalArguments.first as TaskQuery;
        return query.page == 1
            ? page(['a', 'b'])
            : page(['b', 'c'], pageNumber: query.page, total: 3);
      });
    });

    test('appends the next page without duplicates', () async {
      await start();

      await controller.loadMore();

      expect(controller.tasks.map((t) => t.id), ['a', 'b', 'c']);
      expect(controller.query.page, 2);
      expect(controller.hasMore, isFalse);
      expect(controller.isLoadingMore, isFalse);
    });

    test('does nothing when there is no more', () async {
      await start();
      await controller.loadMore();
      clearInteractions(getTasks);

      await controller.loadMore();

      verifyNever(() => getTasks(any()));
    });

    test('ignores a second request while one is running', () async {
      await start();
      final gate = Completer<Loaded<PagedResult<Task>>>();
      when(() => getTasks(any())).thenAnswer((_) => gate.future);
      clearInteractions(getTasks);

      final first = controller.loadMore();
      await controller.loadMore();
      gate.complete(page(['c'], pageNumber: 2, total: 3));
      await first;

      verify(() => getTasks(any())).called(1);
    });

    test('a failure is shown at the end and can be retried', () async {
      await start();
      when(() => getTasks(any())).thenThrow(const NetworkFailure());

      await controller.loadMore();

      expect(controller.loadMoreError, AppStrings.failureNetwork);
      expect(controller.tasks, hasLength(2));
      expect(controller.query.page, 1);

      when(() => getTasks(any()))
          .thenAnswer((_) async => page(['c'], pageNumber: 2, total: 3));
      await controller.loadMore();
      expect(controller.loadMoreError, isNull);
      expect(controller.tasks, hasLength(3));
    });

    test('a page that arrives after a reload is discarded', () async {
      await start();
      final slow = Completer<Loaded<PagedResult<Task>>>();
      when(() => getTasks(any(that: predicate<TaskQuery>((q) => q.page == 2))))
          .thenAnswer((_) => slow.future);

      final loadingMore = controller.loadMore();
      when(() => getTasks(any(that: predicate<TaskQuery>((q) => q.page == 1))))
          .thenAnswer((_) async => page(['x']));
      await controller.reload();
      slow.complete(page(['late'], pageNumber: 2, total: 3));
      await loadingMore;

      expect(controller.tasks.map((t) => t.id), ['x']);
    });
  });

  group('filters', () {
    test('applying filters restarts from the first page', () async {
      when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
      await start();

      await controller.applyFilters(
        const TaskFilterSelection(
          statuses: {TaskStatus.done},
          priorities: {TaskPriority.low},
          sort: TaskSort.priority,
        ),
      );

      final query =
          verify(() => getTasks(captureAny())).captured.last as TaskQuery;
      expect(query.page, 1);
      expect(query.statuses, {TaskStatus.done});
      expect(query.priorities, {TaskPriority.low});
      expect(query.sort, TaskSort.priority);
      expect(controller.hasFilters, isTrue);
      expect(updates, contains(TaskListController.filtersId));
    });

    test('clearing removes filters but keeps the project', () async {
      Get.parameters = <String, String?>{'projectId': 'p2'};
      when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
      await start();
      await controller.applyFilters(
        const TaskFilterSelection(
          statuses: {TaskStatus.done},
          priorities: {},
          sort: TaskSort.dueDateAscending,
        ),
      );

      await controller.clearFilters();

      final query =
          verify(() => getTasks(captureAny())).captured.last as TaskQuery;
      expect(query.statuses, isEmpty);
      expect(query.projectId, 'p2');
    });

    test('the project from the route is used from the start', () async {
      Get.parameters = <String, String?>{'projectId': 'p9'};
      when(() => getTasks(any())).thenAnswer((_) async => page(['a']));

      await start();

      final query =
          verify(() => getTasks(captureAny())).captured.first as TaskQuery;
      expect(query.projectId, 'p9');
    });
  });

  group('search', () {
    test('waits for typing to stop and sends only the last text', () {
      fakeAsync((async) {
        when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
        controller.onInit();
        async.flushMicrotasks();
        clearInteractions(getTasks);

        controller.onSearchChanged('lo');
        async.elapse(AppDurations.searchDebounce ~/ 2);
        controller.onSearchChanged('login');
        async.elapse(AppDurations.searchDebounce ~/ 2);
        verifyNever(() => getTasks(any()));

        async.elapse(AppDurations.searchDebounce);
        async.flushMicrotasks();
        final query =
            verify(() => getTasks(captureAny())).captured.single as TaskQuery;
        expect(query.search, 'login');
      });
    });

    test('searching for the same text again does nothing', () {
      fakeAsync((async) {
        when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
        controller.onInit();
        async.flushMicrotasks();
        controller.onSearchChanged('bug');
        async.elapse(AppDurations.searchDebounce * 2);
        async.flushMicrotasks();
        clearInteractions(getTasks);

        controller.onSearchChanged('  bug ');
        async.elapse(AppDurations.searchDebounce * 2);
        async.flushMicrotasks();

        verifyNever(() => getTasks(any()));
      });
    });
  });

  group('responses that arrive out of order', () {
    test('only the latest request is shown', () async {
      when(() => getTasks(any())).thenAnswer((_) async => page(['start']));
      await start();
      final slow = Completer<Loaded<PagedResult<Task>>>();
      final fast = Completer<Loaded<PagedResult<Task>>>();
      final answers = [slow, fast];
      when(() => getTasks(any())).thenAnswer((_) => answers.removeAt(0).future);

      final older = controller.reload();
      final newer = controller.reload();
      fast.complete(page(['new']));
      await newer;
      slow.complete(page(['old']));
      await older;

      expect(controller.tasks.map((t) => t.id), ['new']);
    });
  });

  group('pending changes', () {
    test('tracks the count and shows it', () async {
      when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
      await start();

      pending.add(2);
      await pumpEventQueue();

      expect(controller.pendingChanges, 2);
      expect(updates, contains(TaskListController.bannerId));
    });

    test('reloads when changes have been delivered', () async {
      when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
      await start();
      pending.add(2);
      await pumpEventQueue();
      clearInteractions(getTasks);

      pending.add(1);
      await pumpEventQueue();

      verify(() => getTasks(any())).called(1);
    });

    test('does not reload when more changes are added', () async {
      when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
      await start();
      clearInteractions(getTasks);

      pending.add(1);
      pending.add(3);
      await pumpEventQueue();

      verifyNever(() => getTasks(any()));
    });
  });

  test('state changes rebuild only the targeted parts', () async {
    when(() => getTasks(any())).thenAnswer((_) async => page(['a']));
    await start();
    expect(updates.toSet(), {
      TaskListController.listId,
      TaskListController.bannerId,
    });
  });
}
