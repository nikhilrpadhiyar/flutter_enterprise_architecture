import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
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

  Finder tile(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Card));

  group('content', () {
    testWidgets('greets the user and shows loading first', (tester) async {
      final gate = Completer<void>();
      backend.adapter.reset();
      backend.adapter.onGet(RegExp(r'/v1/dashboard/summary$'), (call) async {
        await gate.future;
        return FakeDashboard.response(backend);
      });
      await openRoute(tester, RouteNames.dashboard, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await settleApp(tester);

      expect(find.text(AppStrings.greeting('Ada')), findsOneWidget);
    });

    testWidgets('shows the headline figures', (tester) async {
      backend.tasks
        ..clear()
        ..addAll(<Map<String, Object?>>[
          taskJson(id: 'a'),
          taskJson(id: 'b'),
          taskJson(id: 'c', status: 'done'),
          taskJson(
            id: 'd',
            dueDate: DateTime.now()
                .subtract(const Duration(days: 2))
                .toUtc()
                .toIso8601String(),
          ),
        ]);

      await openRoute(tester, RouteNames.dashboard);

      expect(
        find.descendant(
          of: tile(AppStrings.projectsLabel),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile(AppStrings.openTasks),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile(AppStrings.completedLabel),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile(AppStrings.overdueLabel),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists pending and completed tasks and recent activity', (
      tester,
    ) async {
      backend.tasks
        ..clear()
        ..addAll(<Map<String, Object?>>[
          taskJson(id: 'a', title: 'Open one'),
          taskJson(id: 'b', title: 'Finished one', status: 'done'),
        ]);

      await openRoute(tester, RouteNames.dashboard);

      expect(find.text(AppStrings.pendingTasks), findsOneWidget);
      expect(find.text('Open one'), findsOneWidget);
      expect(find.text(AppStrings.completedTasks), findsOneWidget);
      expect(find.text('Finished one'), findsOneWidget);
      expect(find.text(AppStrings.recentActivity), findsOneWidget);
      expect(find.textContaining('moved to todo'), findsWidgets);
    });

    testWidgets('each section says so when it is empty', (tester) async {
      backend.tasks.clear();

      await openRoute(tester, RouteNames.dashboard);

      expect(find.text(AppStrings.noPendingTasks), findsOneWidget);
      expect(find.text(AppStrings.noCompletedTasks), findsOneWidget);
      expect(find.text(AppStrings.noRecentActivity), findsOneWidget);
    });

    testWidgets('shows an error with retry', (tester) async {
      backend.offline = true;
      await openRoute(tester, RouteNames.dashboard);
      expect(find.text(AppStrings.failureNetwork), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text(AppStrings.tryAgain));
      await settleApp(tester);

      expect(find.text(AppStrings.pendingTasks), findsOneWidget);
    });

    testWidgets(
      'keeps the figures and says so when the server is unreachable',
      (tester) async {
        await openRoute(tester, RouteNames.dashboard);
        backend.offline = true;

        await tester.tap(find.byTooltip(AppStrings.tryAgain));
        await settleApp(tester);

        expect(find.text(AppStrings.pendingTasks), findsOneWidget);
        expect(find.text(AppStrings.staleData), findsOneWidget);
      },
    );

    testWidgets('a failed first load shows the error', (tester) async {
      backend.adapter.reset();
      backend.adapter.onGet(
        RegExp(r'/v1/dashboard/summary$'),
        (call) => FakeDashboard.forbidden(),
      );

      await openRoute(tester, RouteNames.dashboard);

      expect(find.text(AppStrings.failureForbidden), findsOneWidget);
    });

    testWidgets(
      'after any failed reload the saved copy is shown with a notice',
      (tester) async {
        // flutter_network_plus serves its cached copy after any failed request
        // under the network-first policy, not only lost connections.
        await openRoute(tester, RouteNames.dashboard);
        backend.adapter.reset();
        backend.adapter.onGet(
          RegExp(r'/v1/dashboard/summary$'),
          (call) => FakeDashboard.forbidden(),
        );

        await tester.tap(find.byTooltip(AppStrings.tryAgain));
        await settleApp(tester);

        expect(find.text(AppStrings.pendingTasks), findsOneWidget);
        expect(find.text(AppStrings.staleData), findsOneWidget);
      },
    );

    testWidgets('pull to refresh reloads', (tester) async {
      await openRoute(tester, RouteNames.dashboard);
      final before = backend.callsTo('/dashboard/summary').length;

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await settleApp(tester);

      expect(backend.callsTo('/dashboard/summary').length, greaterThan(before));
    });
  });

  group('navigation', () {
    testWidgets('the new task shortcut opens the form and reloads on return', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.dashboard);
      final before = backend.callsTo('/dashboard/summary').length;

      await tester.tap(find.widgetWithText(FilledButton, AppStrings.newTask));
      await settleApp(tester);
      expect(find.text(AppStrings.taskTitleLabel), findsOneWidget);

      Get.back<void>();
      await settleApp(tester);

      expect(backend.callsTo('/dashboard/summary').length, greaterThan(before));
    });

    testWidgets('the task shortcuts open the lists', (tester) async {
      await openRoute(tester, RouteNames.dashboard);
      await tester.tap(
        find.widgetWithText(OutlinedButton, AppStrings.allTasks),
      );
      await settleApp(tester);
      expect(Get.currentRoute, RouteNames.tasks);
    });

    testWidgets('the projects shortcut opens the project list', (tester) async {
      await openRoute(tester, RouteNames.dashboard);
      await tester.tap(
        find.widgetWithText(OutlinedButton, AppStrings.projectsLabel),
      );
      await settleApp(tester);
      expect(Get.currentRoute, RouteNames.projects);
    });

    testWidgets('tapping a pending task opens it', (tester) async {
      await openRoute(tester, RouteNames.dashboard);
      await tester.tap(find.text('Write spec').first);
      await settleApp(tester);
      expect(find.text(AppStrings.taskDetailTitle), findsOneWidget);
    });

    testWidgets('the navigation bar reaches the profile', (tester) async {
      await openRoute(tester, RouteNames.dashboard);
      await tester.tap(find.text(AppStrings.navProfile).last);
      await settleApp(tester);
      expect(Get.currentRoute, RouteNames.profile);
    });
  });

  group('layout', () {
    testWidgets('wide screens use two columns and a rail', (tester) async {
      await openRoute(tester, RouteNames.dashboard, size: TestScreens.desktop);

      expect(find.byType(NavigationRail), findsOneWidget);
      final actions = tester.getTopLeft(find.text(AppStrings.quickActions)).dx;
      final tasks = tester.getTopLeft(find.text(AppStrings.pendingTasks)).dx;
      expect(actions, greaterThan(tasks));
    });

    testWidgets('phones use a single column', (tester) async {
      await openRoute(tester, RouteNames.dashboard);
      final actions = tester.getTopLeft(find.text(AppStrings.quickActions)).dx;
      final tasks = tester.getTopLeft(find.text(AppStrings.pendingTasks)).dx;
      expect(actions, tasks);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      await openRoute(tester, RouteNames.dashboard, size: const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('summary tiles are announced with their numbers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openRoute(tester, RouteNames.dashboard);
      expect(
        find.bySemanticsLabel(RegExp('${AppStrings.openTasks}: 1')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
