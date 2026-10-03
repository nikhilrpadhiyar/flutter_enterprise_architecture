import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/session_local_data_source.dart';
import 'package:flutter_enterprise_architecture/data/models/user_model.dart';
import 'package:flutter_enterprise_architecture/domain/entities/app_theme_mode.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/preferences_repository.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/create_task_use_case.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_enterprise_architecture/features/settings/controllers/theme_controller.dart';
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

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, AppStrings.saveChanges);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await settleApp(tester);
  }

  group('profile', () {
    testWidgets('shows who is signed in', (tester) async {
      await openRoute(tester, RouteNames.profile);

      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(
        find.text('${AppStrings.roleLabel}: ${AppStrings.roleMember}'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field(AppStrings.nameLabel)).controller?.text,
        'Ada Lovelace',
      );
    });

    testWidgets('saving sends the name and phone and updates the session', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.profile);

      await tester.enterText(field(AppStrings.nameLabel), 'Ada L.');
      await tester.enterText(field(AppStrings.phoneLabel), '555-0100');
      await save(tester);

      final patch = backend
          .callsTo('/profile')
          .lastWhere((c) => c.method.value == 'PATCH');
      expect(patch.bodyJson, <String, Object?>{
        'name': 'Ada L.',
        'phone': '555-0100',
      });
      expect(di.messenger.messages, <String>[AppStrings.profileUpdated]);
      expect(Get.find<SessionController>().user?.name, 'Ada L.');
      expect(find.text('Ada L.'), findsWidgets);
    });

    testWidgets('a blank name is rejected without a request', (tester) async {
      await openRoute(tester, RouteNames.profile);

      await tester.enterText(field(AppStrings.nameLabel), '  ');
      await save(tester);

      expect(find.text(AppStrings.requiredField), findsOneWidget);
      expect(
        backend.callsTo('/profile').where((c) => c.method.value == 'PATCH'),
        isEmpty,
      );
    });

    testWidgets('editing a field clears its error', (tester) async {
      await openRoute(tester, RouteNames.profile);
      await tester.enterText(field(AppStrings.nameLabel), '');
      await save(tester);
      expect(find.text(AppStrings.requiredField), findsOneWidget);

      await tester.enterText(field(AppStrings.nameLabel), 'A');
      await tester.pump();

      expect(find.text(AppStrings.requiredField), findsNothing);
    });

    testWidgets('server field errors appear on the field', (tester) async {
      await openRoute(tester, RouteNames.profile);
      backend.failWritesWith = 422;

      await tester.enterText(field(AppStrings.nameLabel), 'Someone');
      await save(tester);

      expect(find.text('Server says no'), findsOneWidget);
      expect(di.messenger.messages, isEmpty);
    });

    testWidgets('other server errors show a banner', (tester) async {
      await openRoute(tester, RouteNames.profile);
      backend.failWritesWith = 500;

      await tester.enterText(field(AppStrings.nameLabel), 'Someone');
      await save(tester);

      expect(find.text(AppStrings.failureServer), findsOneWidget);
    });

    testWidgets('shows an error with retry when it cannot be loaded', (
      tester,
    ) async {
      backend.offline = true;
      await openRoute(tester, RouteNames.profile);
      expect(find.text(AppStrings.failureNetwork), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text(AppStrings.tryAgain));
      await settleApp(tester);

      expect(find.text('ada@example.com'), findsOneWidget);
    });

    testWidgets('uses the saved profile with a notice when offline', (
      tester,
    ) async {
      await tester.runAsync(
        () => Get.find<SessionLocalDataSource>().saveUser(
          UserModel.fromJson(userJson()),
        ),
      );
      backend.offline = true;

      await openRoute(tester, RouteNames.profile);

      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text(AppStrings.staleData), findsOneWidget);
    });

    testWidgets('locks the form while saving', (tester) async {
      final gate = Completer<void>();
      backend.holdProfileWrite = gate;
      await openRoute(tester, RouteNames.profile);
      final button = find.widgetWithText(FilledButton, AppStrings.saveChanges);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.tap(button);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextField>(field(AppStrings.nameLabel)).enabled,
        isFalse,
      );

      gate.complete();
      await settleApp(tester);
      expect(
        tester.widget<TextField>(field(AppStrings.nameLabel)).enabled,
        isTrue,
      );
    });
  });

  group('appearance', () {
    Future<void> choose(WidgetTester tester, String label) async {
      final option = find.text(label);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await settleApp(tester);
    }

    testWidgets('starts on the system theme', (tester) async {
      await openRoute(tester, RouteNames.profile);
      expect(Get.find<ThemeController>().mode, AppThemeMode.system);
      final selector = tester.widget<SegmentedButton<AppThemeMode>>(
        find.byType(SegmentedButton<AppThemeMode>),
      );
      expect(selector.selected, <AppThemeMode>{AppThemeMode.system});
    });

    testWidgets('choosing dark switches the theme now and saves it', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.profile);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );

      await choose(tester, AppStrings.themeDark);

      expect(Get.find<ThemeController>().mode, AppThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      final saved = await tester.runAsync(
        () => Get.find<PreferencesRepository>().getThemeMode(),
      );
      expect(saved, AppThemeMode.dark);
    });

    testWidgets('choosing light after dark switches back', (tester) async {
      await openRoute(tester, RouteNames.profile);
      await choose(tester, AppStrings.themeDark);

      await choose(tester, AppStrings.themeLight);

      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
    });
  });

  group('signing out', () {
    Future<void> openSignOutDialog(WidgetTester tester) async {
      final button = find.widgetWithText(OutlinedButton, AppStrings.signOut);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, then signs out and shows the sign in screen', (
      tester,
    ) async {
      await openRoute(tester, RouteNames.profile);

      await openSignOutDialog(tester);
      expect(find.text(AppStrings.signOutTitle), findsOneWidget);
      expect(find.text(AppStrings.signOutMessage), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.signOut));
      await settleApp(tester);

      expect(Get.currentRoute, RouteNames.login);
      expect(Get.find<SessionController>().isSignedIn, isFalse);
      expect(await di.tokens.read(), isNull);
    });

    testWidgets('cancelling stays signed in', (tester) async {
      await openRoute(tester, RouteNames.profile);

      await openSignOutDialog(tester);
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, RouteNames.profile);
      expect(Get.find<SessionController>().isSignedIn, isTrue);
    });

    testWidgets('warns when changes are waiting to sync', (tester) async {
      backend.offline = true;
      di.connectivity.online = false;
      await tester.runAsync(
        () => Get.find<CreateTaskUseCase>()(
          const CreateTaskRequest(
            title: 'Unsent',
            projectId: 'p1',
            priority: TaskPriority.low,
          ),
        ),
      );
      await tester.runAsync(
        () => Get.find<SessionLocalDataSource>().saveUser(
          UserModel.fromJson(userJson()),
        ),
      );
      await openRoute(tester, RouteNames.profile);

      await openSignOutDialog(tester);

      expect(find.text(AppStrings.signOutWithPending(1)), findsOneWidget);
    });

    testWidgets('does not touch the saved theme', (tester) async {
      await openRoute(tester, RouteNames.profile);
      final dark = find.text(AppStrings.themeDark);
      await tester.ensureVisible(dark);
      await tester.pumpAndSettle();
      await tester.tap(dark);
      await settleApp(tester);

      await openSignOutDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.signOut));
      await settleApp(tester);

      final saved = await tester.runAsync(
        () => Get.find<PreferencesRepository>().getThemeMode(),
      );
      expect(saved, AppThemeMode.dark);
    });
  });

  group('layout', () {
    testWidgets('fits a small phone at large text', (tester) async {
      await openRoute(tester, RouteNames.profile, size: const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the rail on large screens', (tester) async {
      await openRoute(tester, RouteNames.profile, size: TestScreens.desktop);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
}
