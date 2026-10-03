import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_backend.dart';
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
      find.widgetWithText(TextField, AppStrings.searchProjects);

  group('project list', () {
    testWidgets('shows each project with its status, counts and progress', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openRoute(tester, RouteNames.projects);

      expect(find.text('Launch'), findsOneWidget);
      expect(find.text('Platform migration'), findsOneWidget);
      expect(find.text(AppStrings.projectActive), findsNWidgets(2));
      expect(find.text(AppStrings.taskCount(10)), findsNWidgets(2));
      expect(find.text(AppStrings.overdueCount(1)), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(RegExp(AppStrings.percentComplete(40))),
        findsNWidgets(2),
      );
      semantics.dispose();
    });

    testWidgets('searching sends the text', (tester) async {
      await openRoute(tester, RouteNames.projects);

      await tester.enterText(searchField(), 'platform');
      await tester.pump(const Duration(milliseconds: 450));
      await settleApp(tester);

      final call = backend.callsTo('/projects').last;
      expect(call.uri.queryParameters['q'], 'platform');
      expect(find.text('Platform migration'), findsOneWidget);
      expect(find.text('Launch'), findsNothing);
    });

    testWidgets('a search with no results offers to clear it', (tester) async {
      await openRoute(tester, RouteNames.projects);
      await tester.enterText(searchField(), 'zzz');
      await tester.pump(const Duration(milliseconds: 450));
      await settleApp(tester);
      expect(find.text(AppStrings.noMatchingProjectsTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.clearFilters));
      await settleApp(tester);

      expect(find.text('Launch'), findsOneWidget);
    });

    testWidgets('shows the empty state', (tester) async {
      backend.projects.clear();
      await openRoute(tester, RouteNames.projects);
      expect(find.text(AppStrings.noProjectsTitle), findsOneWidget);
    });

    testWidgets('shows an error with retry', (tester) async {
      backend.offline = true;
      await openRoute(tester, RouteNames.projects);
      expect(find.text(AppStrings.failureNetwork), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text(AppStrings.tryAgain));
      await settleApp(tester);

      expect(find.text('Launch'), findsOneWidget);
    });

    testWidgets('shows saved projects with a notice when offline', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.projects);
      backend.offline = true;

      await tester.tap(find.byTooltip(AppStrings.tryAgain));
      await settleApp(tester);

      expect(find.text('Launch'), findsOneWidget);
      expect(find.text(AppStrings.staleData), findsOneWidget);
    });

    testWidgets('the refresh button reloads', (tester) async {
      await openRoute(tester, RouteNames.projects);
      final before = backend.callsTo('/projects').length;
      backend.projects.add(<String, Object?>{
        ...backend.projects.first,
        'id': 'p3',
        'name': 'Added',
      });

      await tester.tap(find.byTooltip(AppStrings.tryAgain));
      await settleApp(tester);

      expect(backend.callsTo('/projects').length, greaterThan(before));
      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('large screens use a navigation rail', (tester) async {
      await openRoute(tester, RouteNames.projects, size: TestScreens.desktop);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Launch'), findsOneWidget);
    });
  });

  group('project detail', () {
    testWidgets('shows the project and a preview of its tasks', (tester) async {
      await openRoute(tester, RouteNames.projectPath('p1'));

      expect(find.text('Launch'), findsWidgets);
      expect(find.text('Ship v1'), findsOneWidget);
      expect(find.text(AppStrings.projectActive), findsOneWidget);
      expect(find.text(AppStrings.projectTasks), findsOneWidget);
      expect(find.text('Write spec'), findsOneWidget);
      expect(find.text(AppStrings.viewAllTasks), findsNothing);
    });

    testWidgets('offers the full task list when there are more tasks', (
      tester,
    ) async {
      backend.tasks
        ..clear()
        ..addAll(FakeBackend.manyTasks(8));
      await openRoute(tester, RouteNames.projectPath('p1'));

      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 6'), findsNothing);

      await tester.ensureVisible(find.text(AppStrings.viewAllTasks));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.viewAllTasks));
      await settleApp(tester);

      expect(
        backend.callsTo('/tasks').last.uri.queryParameters['projectId'],
        'p1',
      );
      expect(find.text(AppStrings.tasksTitle), findsWidgets);
    });

    testWidgets('says when the project has no tasks', (tester) async {
      backend.tasks.clear();
      await openRoute(tester, RouteNames.projectPath('p1'));
      expect(find.text(AppStrings.projectHasNoTasks), findsOneWidget);
    });

    testWidgets('tapping a task opens it', (tester) async {
      await openRoute(tester, RouteNames.projectPath('p1'));

      await tester.tap(find.text('Write spec'));
      await settleApp(tester);

      expect(find.text(AppStrings.taskDetailTitle), findsOneWidget);
    });

    testWidgets('shows an error for an unknown project', (tester) async {
      await openRoute(tester, RouteNames.projectPath('missing'));
      expect(find.text(AppStrings.failureNotFound), findsOneWidget);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      await openRoute(
        tester,
        RouteNames.projectPath('p1'),
        size: const Size(320, 568),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
