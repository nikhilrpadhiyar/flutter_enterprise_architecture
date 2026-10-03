import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/json_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/task_models.dart';
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

  Future<void> choose<T>(WidgetTester tester, T from, String option) async {
    await tester.tap(find.byType(DropdownButtonFormField<T>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await settleApp(tester);
  }

  group('content', () {
    testWidgets('shows every field, attachment and activity entry', (
      tester,
    ) async {
      backend.tasks
        ..clear()
        ..add(
          taskJson(
            dueDate: DateTime.now()
                .add(const Duration(days: 4))
                .toUtc()
                .toIso8601String(),
          ),
        );

      await openRoute(tester, RouteNames.taskPath('t1'));

      expect(find.text('Write spec'), findsOneWidget);
      expect(find.text(AppStrings.statusTodo), findsOneWidget);
      expect(find.text(AppStrings.priorityHigh), findsOneWidget);
      expect(
        find.textContaining('Ada Lovelace', findRichText: true),
        findsWidgets,
      );
      expect(find.text('Draft the spec'), findsOneWidget);
      expect(find.text('spec.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
      expect(find.textContaining('moved to todo'), findsOneWidget);
      expect(find.textContaining('did a new thing'), findsOneWidget);
      expect(
        find.textContaining(AppStrings.overdue, findRichText: true),
        findsNothing,
      );
    });

    testWidgets('shows placeholders when there is nothing to list', (
      tester,
    ) async {
      backend.tasks
        ..clear()
        ..add(
          taskJson(assignee: null)
            ..['attachments'] = <Object?>[]
            ..['activity'] = <Object?>[]
            ..['description'] = '',
        );

      await openRoute(tester, RouteNames.taskPath('t1'));

      expect(find.text(AppStrings.noAttachments), findsOneWidget);
      expect(find.text(AppStrings.noActivity), findsOneWidget);
      expect(
        find.textContaining(AppStrings.unassigned, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(AppStrings.noDueDate, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('marks an overdue task', (tester) async {
      backend.tasks
        ..clear()
        ..add(
          taskJson(
            dueDate: DateTime.now()
                .subtract(const Duration(days: 2))
                .toUtc()
                .toIso8601String(),
          ),
        );
      await openRoute(tester, RouteNames.taskPath('t1'));
      expect(
        find.textContaining(AppStrings.overdue, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows an error with retry when the task does not exist', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.taskPath('missing'));
      expect(find.text(AppStrings.failureNotFound), findsOneWidget);
      expect(find.text(AppStrings.tryAgain), findsOneWidget);
    });

    testWidgets(
      'shows saved data with a notice when the server is unreachable',
      (tester) async {
        await openRoute(tester, RouteNames.tasks);
        backend.offline = true;

        await tester.tap(find.text('Write spec'));
        await settleApp(tester);

        expect(find.text('Write spec'), findsWidgets);
        expect(find.text(AppStrings.staleData), findsOneWidget);
      },
    );
  });

  group('quick changes', () {
    testWidgets('changing the status sends only the status', (tester) async {
      await openRoute(tester, RouteNames.taskPath('t1'));

      await choose<TaskStatus>(tester, TaskStatus.todo, AppStrings.statusDone);

      final patch = backend.callsTo('/tasks/t1').last;
      expect(patch.bodyJson, <String, Object?>{'status': 'done'});
      expect(find.text(AppStrings.statusDone), findsOneWidget);
    });

    testWidgets('changing the priority sends only the priority', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.taskPath('t1'));

      await choose<TaskPriority>(
        tester,
        TaskPriority.high,
        AppStrings.priorityUrgent,
      );

      expect(backend.callsTo('/tasks/t1').last.bodyJson, <String, Object?>{
        'priority': 'urgent',
      });
    });

    testWidgets('a rejected change shows an error and keeps the old value', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.taskPath('t1'));
      backend.failWritesWith = 500;

      await choose<TaskStatus>(tester, TaskStatus.todo, AppStrings.statusDone);

      expect(find.text(AppStrings.failureServer), findsOneWidget);
      expect(find.text(AppStrings.statusTodo), findsOneWidget);
    });

    testWidgets('a change made offline is shown as waiting to sync', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.taskPath('t1'));
      backend.offline = true;
      di.connectivity.online = false;

      await choose<TaskStatus>(tester, TaskStatus.todo, AppStrings.statusDone);

      expect(find.text(AppStrings.statusDone), findsOneWidget);
      expect(find.text(AppStrings.waitingToSync), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('asks for confirmation, then deletes and returns to the list', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.tasks);
      await tester.tap(find.text('Write spec'));
      await settleApp(tester);

      await tester.tap(find.byTooltip(AppStrings.delete));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.deleteTaskTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
      await settleApp(tester);

      expect(backend.callsTo('/tasks/t1').last.method.value, 'DELETE');
      expect(backend.tasks, isEmpty);
      expect(find.text(AppStrings.noTasksTitle), findsOneWidget);
      expect(di.messenger.messages, <String>[AppStrings.taskDeleted]);
    });

    testWidgets('cancelling keeps the task', (tester) async {
      await openRoute(tester, RouteNames.taskPath('t1'));

      await tester.tap(find.byTooltip(AppStrings.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      expect(backend.tasks, hasLength(1));
      expect(
        backend.callsTo('/tasks/t1').where((c) => c.method.value == 'DELETE'),
        isEmpty,
      );
    });

    testWidgets('a refused deletion shows an error', (tester) async {
      await openRoute(tester, RouteNames.taskPath('t1'));
      backend.failWritesWith = 500;

      await tester.tap(find.byTooltip(AppStrings.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
      await settleApp(tester);

      expect(find.text(AppStrings.failureServer), findsOneWidget);
      expect(find.text('Write spec'), findsWidgets);
    });
  });

  group('tasks that are not confirmed by the server', () {
    Future<void> seedLocal(WidgetTester tester, {required bool failed}) async {
      final local = Get.find<TaskLocalDataSource>();
      await tester.runAsync(() async {
        await local.beginChange(
          key: 'k1',
          kind: PendingKind.create,
          task: taskModel(id: 'local-k1', title: 'Only on this device'),
          now: DateTime.now(),
        );
        if (failed) await local.failChange('k1');
      });
    }

    testWidgets('a waiting task cannot be edited or deleted yet', (
      tester,
    ) async {
      backend.tasks.clear();
      await seedLocal(tester, failed: false);

      await openRoute(tester, RouteNames.taskPath('local-k1'));

      expect(find.text('Only on this device'), findsOneWidget);
      expect(find.text(AppStrings.waitingToSync), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.edit_outlined),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a rejected task can be discarded', (tester) async {
      backend.tasks.clear();
      await seedLocal(tester, failed: true);
      await openRoute(tester, RouteNames.tasks);
      expect(find.text(AppStrings.notSaved), findsOneWidget);

      await tester.tap(find.text('Only on this device'));
      await settleApp(tester);
      expect(find.text(AppStrings.changeRejected), findsOneWidget);

      await tester.tap(find.text(AppStrings.discardChanges));
      await settleApp(tester);

      expect(find.text('Only on this device'), findsNothing);
      expect(find.text(AppStrings.noTasksTitle), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('fits a small phone at large text', (tester) async {
      await openRoute(
        tester,
        RouteNames.taskPath('t1'),
        size: const Size(320, 568),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('is readable on a wide screen', (tester) async {
      await openRoute(
        tester,
        RouteNames.taskPath('t1'),
        size: TestScreens.desktop,
      );
      expect(find.text('Write spec'), findsOneWidget);
    });
  });
}
