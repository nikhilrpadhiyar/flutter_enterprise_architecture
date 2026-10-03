import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> pick<T>(WidgetTester tester, String option) async {
    await tester.ensureVisible(find.byType(DropdownButtonFormField<T>));
    await tester.tap(find.byType(DropdownButtonFormField<T>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  /// Taps the form's submit button. The label may also appear in the app
  /// bar and on screens underneath, so the button is found by type.
  Future<void> save(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label).last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settleApp(tester);
  }

  Future<void> openCreateFromList(WidgetTester tester) async {
    await openRoute(tester, RouteNames.tasks);
    await tester.tap(find.byType(FloatingActionButton));
    await settleApp(tester);
  }

  Future<void> openEditFromDetail(WidgetTester tester) async {
    await openRoute(tester, RouteNames.tasks);
    await tester.tap(find.text('Write spec'));
    await settleApp(tester);
    await tester.tap(find.byTooltip(AppStrings.edit));
    await settleApp(tester);
  }

  group('creating', () {
    testWidgets('shows every field with a medium priority', (tester) async {
      await openCreateFromList(tester);

      for (final label in <String>[
        AppStrings.taskTitleLabel,
        AppStrings.descriptionLabel,
      ]) {
        expect(field(label), findsOneWidget, reason: label);
      }
      expect(find.text(AppStrings.projectLabel), findsOneWidget);
      expect(find.text(AppStrings.assigneeLabel), findsOneWidget);
      expect(find.text(AppStrings.priorityMedium), findsOneWidget);
      expect(find.text(AppStrings.setDueDate), findsOneWidget);
    });

    testWidgets('an empty submit lists the problems and sends nothing', (
      tester,
    ) async {
      await openCreateFromList(tester);

      await save(tester, AppStrings.newTask);

      expect(find.text(AppStrings.requiredField), findsNWidgets(2));
      expect(
        backend.callsTo('/tasks').where((c) => c.method.value == 'POST'),
        isEmpty,
      );
    });

    testWidgets('editing a field clears its error', (tester) async {
      await openCreateFromList(tester);
      await save(tester, AppStrings.newTask);
      expect(find.text(AppStrings.requiredField), findsNWidgets(2));

      await tester.enterText(field(AppStrings.taskTitleLabel), 'x');
      await tester.pump();

      expect(find.text(AppStrings.requiredField), findsOneWidget);
    });

    testWidgets('creates the task and returns to the list', (tester) async {
      await openCreateFromList(tester);

      await tester.enterText(
        field(AppStrings.taskTitleLabel),
        '  Plan launch ',
      );
      await tester.enterText(field(AppStrings.descriptionLabel), 'All hands');
      await pick<String>(tester, 'Platform migration');
      await pick<String?>(tester, 'Grace Hopper');
      await pick<TaskPriority>(tester, AppStrings.priorityUrgent);
      await save(tester, AppStrings.newTask);

      final post = backend
          .callsTo('/tasks')
          .lastWhere((c) => c.method.value == 'POST');
      expect(post.bodyJson, <String, Object?>{
        'title': 'Plan launch',
        'description': 'All hands',
        'projectId': 'p2',
        'priority': 'urgent',
        'assigneeId': 'u2',
      });
      expect(di.messenger.messages, <String>[AppStrings.taskCreated]);
      expect(find.text('Plan launch'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('sends the chosen due date', (tester) async {
      await openCreateFromList(tester);
      await tester.enterText(field(AppStrings.taskTitleLabel), 'With deadline');
      await pick<String>(tester, 'Platform migration');

      await tester.tap(find.text(AppStrings.setDueDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${AppStrings.dueDateLabel}:'),
        findsOneWidget,
      );

      await save(tester, AppStrings.newTask);

      final post = backend
          .callsTo('/tasks')
          .lastWhere((c) => c.method.value == 'POST');
      final today = DateTime.now();
      expect(
        post.bodyJson,
        containsPair(
          'dueDate',
          DateTime.utc(today.year, today.month, today.day).toIso8601String(),
        ),
      );
    });

    testWidgets('the due date can be removed again', (tester) async {
      await openCreateFromList(tester);
      await tester.tap(find.text(AppStrings.setDueDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AppStrings.clearDueDate));
      await tester.pump();

      expect(find.text(AppStrings.setDueDate), findsOneWidget);
    });

    testWidgets('shows server validation errors on the field', (tester) async {
      await openCreateFromList(tester);
      await tester.enterText(field(AppStrings.taskTitleLabel), 'Anything');
      await pick<String>(tester, 'Platform migration');
      backend.failWritesWith = 422;

      await save(tester, AppStrings.newTask);

      expect(find.text('Server says no'), findsOneWidget);
      expect(find.text(AppStrings.taskTitleLabel), findsOneWidget);
      expect(di.messenger.messages, isEmpty);
    });

    testWidgets('shows a banner for other server errors and stays editable', (
      tester,
    ) async {
      await openCreateFromList(tester);
      await tester.enterText(field(AppStrings.taskTitleLabel), 'Anything');
      await pick<String>(tester, 'Platform migration');
      backend.failWritesWith = 500;

      await save(tester, AppStrings.newTask);

      expect(find.text(AppStrings.failureServer), findsOneWidget);
      expect(
        tester.widget<TextField>(field(AppStrings.taskTitleLabel)).enabled,
        isTrue,
      );
    });

    testWidgets('saves on the device when offline and says so', (tester) async {
      await openCreateFromList(tester);
      await tester.enterText(field(AppStrings.taskTitleLabel), 'Offline idea');
      await pick<String>(tester, 'Platform migration');
      backend.offline = true;
      di.connectivity.online = false;

      await save(tester, AppStrings.newTask);

      expect(di.messenger.messages, <String>[AppStrings.taskSavedOffline]);
      expect(find.text('Offline idea'), findsOneWidget);
      expect(find.text(AppStrings.waitingToSync), findsOneWidget);
    });

    testWidgets('locks the form while saving', (tester) async {
      await openCreateFromList(tester);
      await tester.enterText(field(AppStrings.taskTitleLabel), 'Slow one');
      await pick<String>(tester, 'Platform migration');

      final button = find.widgetWithText(FilledButton, AppStrings.newTask).last;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextField>(field(AppStrings.taskTitleLabel)).enabled,
        isFalse,
      );
      await settleApp(tester);
    });
  });

  group('loading the form', () {
    testWidgets('shows an error with retry when options cannot be loaded', (
      tester,
    ) async {
      backend.offline = true;
      await openRoute(tester, RouteNames.taskCreate);
      expect(find.text(AppStrings.failureNetwork), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text(AppStrings.tryAgain));
      await settleApp(tester);

      expect(field(AppStrings.taskTitleLabel), findsOneWidget);
    });

    testWidgets('explains when there is no project to add tasks to', (
      tester,
    ) async {
      backend.projects.clear();
      await openRoute(tester, RouteNames.taskCreate);
      expect(find.text(AppStrings.noProjectsTitle), findsOneWidget);
    });

    testWidgets('still works when the people list is unavailable', (
      tester,
    ) async {
      backend.users.clear();
      await openRoute(tester, RouteNames.taskCreate);
      expect(field(AppStrings.taskTitleLabel), findsOneWidget);
    });

    testWidgets('a project from the route is preselected', (tester) async {
      await openRoute(tester, '${RouteNames.taskCreate}?projectId=p2');
      expect(find.text('Platform migration'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('is prefilled and does not allow moving to another project', (
      tester,
    ) async {
      await openEditFromDetail(tester);

      expect(
        tester
            .widget<TextField>(field(AppStrings.taskTitleLabel))
            .controller
            ?.text,
        'Write spec',
      );
      expect(
        tester
            .widget<TextField>(field(AppStrings.descriptionLabel))
            .controller
            ?.text,
        'Draft the spec',
      );
      expect(find.text(AppStrings.editTaskTitle), findsOneWidget);
      expect(find.text(AppStrings.priorityHigh), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .onChanged,
        isNull,
      );
    });

    testWidgets('sends only what changed', (tester) async {
      await openEditFromDetail(tester);

      await tester.enterText(
        field(AppStrings.taskTitleLabel),
        'Write the spec',
      );
      await save(tester, AppStrings.saveChanges);

      final patch = backend
          .callsTo('/tasks/t1')
          .lastWhere((c) => c.method.value == 'PATCH');
      expect(patch.bodyJson, <String, Object?>{'title': 'Write the spec'});
      expect(di.messenger.messages, <String>[AppStrings.taskUpdated]);
      expect(find.text('Write the spec'), findsWidgets);
    });

    testWidgets('closes without a request when nothing changed', (
      tester,
    ) async {
      await openEditFromDetail(tester);

      await save(tester, AppStrings.saveChanges);

      expect(
        backend.callsTo('/tasks/t1').where((c) => c.method.value == 'PATCH'),
        isEmpty,
      );
      expect(find.text(AppStrings.taskDetailTitle), findsOneWidget);
    });

    testWidgets('can remove the due date', (tester) async {
      backend.tasks
        ..clear()
        ..add(
          taskJson(
            dueDate: DateTime.now()
                .add(const Duration(days: 3))
                .toUtc()
                .toIso8601String(),
          ),
        );
      await openEditFromDetail(tester);

      await tester.tap(find.byTooltip(AppStrings.clearDueDate));
      await tester.pump();
      await save(tester, AppStrings.saveChanges);

      final patch = backend
          .callsTo('/tasks/t1')
          .lastWhere((c) => c.method.value == 'PATCH');
      expect(patch.bodyJson, <String, Object?>{'dueDate': null});
    });

    testWidgets('does not offer to remove an existing assignee', (
      tester,
    ) async {
      await openEditFromDetail(tester);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String?>));
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.unassigned), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('fits a small phone at large text', (tester) async {
      await openRoute(
        tester,
        RouteNames.taskCreate,
        size: const Size(320, 568),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('is centred and bounded on a wide screen', (tester) async {
      await openRoute(tester, RouteNames.taskCreate, size: TestScreens.desktop);
      final width = tester.getSize(field(AppStrings.taskTitleLabel)).width;
      expect(width, lessThan(TestScreens.desktop.width));
    });
  });
}
