import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/create_task_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/json_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_di.dart';

void main() {
  late TestDi di;
  late FakeBackend backend;

  setUp(() async {
    di = await TestDi.create();
    backend = FakeBackend(di.adapter);
    await di.signInUser();
  });
  tearDown(() => di.dispose());

  Finder searchField() =>
      find.widgetWithText(TextField, AppStrings.searchTasks);

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(searchField(), text);
    await tester.pump(const Duration(milliseconds: 450));
    await settleApp(tester);
  }

  group('content', () {
    testWidgets('shows a loader first, then the tasks', (tester) async {
      final gate = Completer<void>();
      backend.holdTaskList = gate;
      await openRoute(tester, RouteNames.tasks, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Write spec'), findsNothing);

      gate.complete();
      await settleApp(tester);

      expect(find.text('Write spec'), findsOneWidget);
      expect(find.text(AppStrings.statusTodo), findsOneWidget);
      expect(find.text(AppStrings.priorityHigh), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('marks overdue tasks', (tester) async {
      backend.tasks
        ..clear()
        ..add(
          taskJson(
            dueDate: DateTime.now()
                .subtract(const Duration(days: 3))
                .toUtc()
                .toIso8601String(),
          ),
        );

      await openRoute(tester, RouteNames.tasks);

      expect(find.textContaining(AppStrings.overdue), findsOneWidget);
    });

    testWidgets('shows unassigned tasks', (tester) async {
      backend.tasks
        ..clear()
        ..add(taskJson(assignee: null));
      await openRoute(tester, RouteNames.tasks);
      expect(find.text(AppStrings.unassigned), findsOneWidget);
    });

    testWidgets('shows the empty state with a way to create a task', (
      tester,
    ) async {
      backend.tasks.clear();
      await openRoute(tester, RouteNames.tasks);

      expect(find.text(AppStrings.noTasksTitle), findsOneWidget);
      expect(find.text(AppStrings.newTask), findsNWidgets(2));
    });

    testWidgets('shows an error with retry when nothing can be loaded', (
      tester,
    ) async {
      backend.offline = true;
      await openRoute(tester, RouteNames.tasks);
      expect(find.text(AppStrings.failureNetwork), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text(AppStrings.tryAgain));
      await settleApp(tester);

      expect(find.text('Write spec'), findsOneWidget);
      expect(find.text(AppStrings.failureNetwork), findsNothing);
    });
  });

  group('search and filters', () {
    setUp(() {
      backend.tasks
        ..clear()
        ..addAll(<Map<String, Object?>>[
          taskJson(id: 'a', title: 'Fix login bug', status: 'inProgress'),
          taskJson(
            id: 'b',
            title: 'Write docs',
            status: 'done',
            priority: 'low',
          ),
        ]);
    });

    testWidgets('searching sends the text once typing stops', (tester) async {
      await openRoute(tester, RouteNames.tasks);
      final before = backend.callsTo('/tasks').length;

      await tester.enterText(searchField(), 'log');
      await tester.enterText(searchField(), 'login');
      await tester.pump(const Duration(milliseconds: 100));
      expect(backend.callsTo('/tasks'), hasLength(before));

      await tester.pump(const Duration(milliseconds: 400));
      await settleApp(tester);

      final calls = backend.callsTo('/tasks');
      expect(calls, hasLength(before + 1));
      expect(calls.last.uri.queryParameters['q'], 'login');
      expect(find.text('Fix login bug'), findsOneWidget);
      expect(find.text('Write docs'), findsNothing);
    });

    testWidgets('a search with no results offers to clear filters', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.tasks);

      await search(tester, 'zzz');
      expect(find.text(AppStrings.noMatchingTasksTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.clearFilters));
      await settleApp(tester);

      expect(find.text('Fix login bug'), findsOneWidget);
      expect(backend.callsTo('/tasks').last.uri.queryParameters['q'], isNull);
      expect(tester.widget<TextField>(searchField()).controller?.text, isEmpty);
    });

    testWidgets('the filter sheet applies status and priority', (tester) async {
      await openRoute(tester, RouteNames.tasks);

      await tester.tap(find.byTooltip(AppStrings.filters));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, AppStrings.statusDone));
      await tester.tap(find.widgetWithText(FilterChip, AppStrings.priorityLow));
      await tester.tap(find.text(AppStrings.sortPriority));
      await tester.pump();
      await tester.tap(find.text(AppStrings.apply));
      await settleApp(tester);

      final query = backend.callsTo('/tasks').last.uri.queryParameters;
      expect(query['status'], 'done');
      expect(query['priority'], 'low');
      expect(query['sort'], 'priority');
      expect(find.text('Write docs'), findsOneWidget);
      expect(find.text('Fix login bug'), findsNothing);
      expect(find.text('3'), findsOneWidget); // filter badge
    });

    testWidgets('the filter sheet remembers choices and can reset', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.tasks);
      await tester.tap(find.byTooltip(AppStrings.filters));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, AppStrings.statusDone));
      await tester.tap(find.text(AppStrings.apply));
      await settleApp(tester);

      await tester.tap(find.byTooltip(AppStrings.filters));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(FilterChip, AppStrings.statusDone),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.text(AppStrings.reset));
      await tester.tap(find.text(AppStrings.apply));
      await settleApp(tester);

      expect(
        backend.callsTo('/tasks').last.uri.queryParameters['status'],
        isNull,
      );
      expect(find.text('Fix login bug'), findsOneWidget);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      await openRoute(tester, RouteNames.tasks);
      final before = backend.callsTo('/tasks').length;

      await tester.tap(find.byTooltip(AppStrings.filters));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(backend.callsTo('/tasks'), hasLength(before));
    });
  });

  group('paging and refreshing', () {
    testWidgets('loads the next page when scrolling to the end', (
      tester,
    ) async {
      backend.tasks
        ..clear()
        ..addAll(FakeBackend.manyTasks(45));
      await openRoute(tester, RouteNames.tasks);
      expect(find.text('Task 1'), findsOneWidget);
      expect(backend.callsTo('/tasks').last.uri.queryParameters['page'], '1');

      await tester.scrollUntilVisible(
        find.text('Task 20'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await settleApp(tester);
      await tester.scrollUntilVisible(
        find.text('Task 25'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await settleApp(tester);

      final pages = backend
          .callsTo('/tasks')
          .map((c) => c.uri.queryParameters['page'])
          .toList();
      expect(pages, contains('2'));
      expect(find.text('Task 25'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the list', (tester) async {
      await openRoute(tester, RouteNames.tasks);
      final before = backend.callsTo('/tasks').length;
      backend.tasks.add(taskJson(id: 'new', title: 'Fresh task'));

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await settleApp(tester);

      expect(backend.callsTo('/tasks').length, greaterThan(before));
      expect(find.text('Fresh task'), findsOneWidget);
    });

    testWidgets('the refresh button reloads the list', (tester) async {
      await openRoute(tester, RouteNames.tasks);
      final before = backend.callsTo('/tasks').length;

      await tester.tap(find.byTooltip(AppStrings.tryAgain));
      await settleApp(tester);

      expect(backend.callsTo('/tasks').length, greaterThan(before));
    });
  });

  group('offline', () {
    testWidgets(
      'shows saved tasks with a notice when the server is unreachable',
      (tester) async {
        await openRoute(tester, RouteNames.tasks);
        expect(find.text(AppStrings.staleData), findsNothing);

        backend.offline = true;
        await tester.tap(find.byTooltip(AppStrings.tryAgain));
        await settleApp(tester);

        expect(find.text('Write spec'), findsOneWidget);
        expect(find.text(AppStrings.staleData), findsOneWidget);
        expect(find.text(AppStrings.failureNetwork), findsNothing);
      },
    );

    testWidgets('lists a task created offline as waiting to sync', (
      tester,
    ) async {
      backend.offline = true;
      di.connectivity.online = false;
      await tester.runAsync(
        () => Get.find<CreateTaskUseCase>()(
          const CreateTaskRequest(
            title: 'Made offline',
            projectId: 'p1',
            priority: TaskPriority.high,
          ),
        ),
      );

      await openRoute(tester, RouteNames.tasks);

      expect(find.text('Made offline'), findsOneWidget);
      expect(find.text(AppStrings.waitingToSync), findsOneWidget);
      expect(find.text(AppStrings.pendingChanges(1)), findsOneWidget);
    });

    testWidgets(
      '"Sync now" sends waiting changes without waiting for the connection',
      (tester) async {
        backend.offline = true;
        di.connectivity.online = false;
        await tester.runAsync(
          () => Get.find<CreateTaskUseCase>()(
            const CreateTaskRequest(
              title: 'Send me now',
              projectId: 'p1',
              priority: TaskPriority.high,
            ),
          ),
        );
        await openRoute(tester, RouteNames.tasks);
        expect(find.text(AppStrings.pendingChanges(1)), findsOneWidget);

        backend.offline = false;
        await tester.tap(find.text(AppStrings.syncNow));
        await settleApp(tester);

        expect(find.text(AppStrings.pendingChanges(1)), findsNothing);
        expect(find.text(AppStrings.waitingToSync), findsNothing);
        expect(find.text('Send me now'), findsOneWidget);
        expect(
          backend.callsTo('/tasks').where((c) => c.method.value == 'POST'),
          hasLength(1),
        );
      },
    );

    testWidgets('a reload failure keeps the tasks on screen', (tester) async {
      await openRoute(tester, RouteNames.tasks);
      backend.failReadsWith = 403;

      await tester.tap(find.byTooltip(AppStrings.tryAgain));
      await settleApp(tester);

      expect(find.text('Write spec'), findsOneWidget);
      expect(find.text(AppStrings.failureForbidden), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('tapping a task opens it, and the list reloads on return', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.tasks);
      final before = backend.callsTo('/tasks').length;

      await tester.tap(find.text('Write spec'));
      await settleApp(tester);
      expect(find.text(AppStrings.taskDetailTitle), findsOneWidget);

      Get.back<void>();
      await settleApp(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(backend.callsTo('/tasks').length, greaterThan(before));
    });

    testWidgets('the new task button opens the form', (tester) async {
      await openRoute(tester, RouteNames.tasks);

      await tester.tap(find.byType(FloatingActionButton));
      await settleApp(tester);

      expect(find.text(AppStrings.taskTitleLabel), findsOneWidget);
    });

    testWidgets('the bottom bar switches between sections', (tester) async {
      await openRoute(tester, RouteNames.tasks);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.text(AppStrings.navProjects).last);
      await settleApp(tester);

      expect(find.text(AppStrings.searchProjects), findsOneWidget);
    });

    testWidgets('a project filter from the route limits the list', (
      tester,
    ) async {
      backend.tasks
        ..clear()
        ..addAll(<Map<String, Object?>>[
          taskJson(id: 'a', title: 'In p1'),
          taskJson(id: 'b', title: 'In p2', projectId: 'p2'),
        ]);

      await openRoute(tester, RouteNames.tasksOfProject('p2'));

      expect(find.text('In p2'), findsOneWidget);
      expect(find.text('In p1'), findsNothing);
      expect(
        backend.callsTo('/tasks').last.uri.queryParameters['projectId'],
        'p2',
      );
    });
  });

  group('layout', () {
    testWidgets('large screens use a navigation rail', (tester) async {
      await openRoute(tester, RouteNames.tasks, size: TestScreens.desktop);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Write spec'), findsOneWidget);
    });

    testWidgets('survives large text on a small phone', (tester) async {
      await openRoute(tester, RouteNames.tasks, size: const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Write spec'), findsOneWidget);
    });
  });
}
