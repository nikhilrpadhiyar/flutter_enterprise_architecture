import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_sizes.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/auth_finders.dart';
import '../../helpers/json_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_di.dart';
import '../../helpers/test_network.dart';

void main() {
  late TestDi di;

  setUp(() async => di = await TestDi.create());
  tearDown(() => di.dispose());

  Future<void> openLogin(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
    await tester.pumpWidget(
      buildTestApp(
        initialRoute: RouteNames.login,
        extraPages: <GetPage<dynamic>>[],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String email = 'ada@example.com',
    String password = 'Password1',
  }) async {
    await tester.enterText(textFieldLabelled(AppStrings.emailLabel), email);
    await tester.enterText(
      textFieldLabelled(AppStrings.passwordLabel),
      password,
    );
    await tester.tap(find.text(AppStrings.signIn));
    await tester.pumpAndSettle();
  }

  void stubLogin(fnp.MockResponse Function() response) =>
      di.adapter.onPost(TestNetwork.path('auth/login'), (call) => response());

  testWidgets('shows the form from the wireframe', (tester) async {
    await openLogin(tester);

    expect(find.text(AppStrings.signInTitle), findsOneWidget);
    expect(find.text(AppStrings.signInSubtitle), findsOneWidget);
    expect(textFieldLabelled(AppStrings.emailLabel), findsOneWidget);
    expect(textFieldLabelled(AppStrings.passwordLabel), findsOneWidget);
    expect(find.text(AppStrings.signIn), findsOneWidget);
    expect(find.text(AppStrings.goToRegister), findsOneWidget);
    expect(find.text(AppStrings.failureAuthentication), findsNothing);
  });

  testWidgets('empty submit shows field errors and sends nothing', (
    tester,
  ) async {
    await openLogin(tester);

    await tester.tap(find.text(AppStrings.signIn));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.requiredField), findsNWidgets(2));
    expect(di.adapter.capturedRequests, isEmpty);
  });

  testWidgets('a malformed email is reported on the email field', (
    tester,
  ) async {
    await openLogin(tester);

    await fillAndSubmit(tester, email: 'not-an-email');

    expect(find.text(AppStrings.invalidEmail), findsOneWidget);
    expect(di.adapter.capturedRequests, isEmpty);
  });

  testWidgets('editing a field removes its error', (tester) async {
    await openLogin(tester);
    await tester.tap(find.text(AppStrings.signIn));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.requiredField), findsNWidgets(2));

    await tester.enterText(textFieldLabelled(AppStrings.emailLabel), 'a');
    await tester.pump();

    expect(find.text(AppStrings.requiredField), findsOneWidget);
  });

  testWidgets('wrong credentials show a banner and keep the form usable', (
    tester,
  ) async {
    stubLogin(
      () => fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401),
    );
    await openLogin(tester);

    await fillAndSubmit(tester, password: 'WrongPass1');

    expect(find.text(AppStrings.failureAuthentication), findsOneWidget);
    expect(isFieldEnabled(tester, AppStrings.emailLabel), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(Get.currentRoute, isNot(RouteNames.dashboard));
  });

  testWidgets('a network failure shows a banner and can be retried', (
    tester,
  ) async {
    var reachable = false;
    di.adapter.onPost(
      TestNetwork.path('auth/login'),
      (call) => reachable
          ? fnp.MockResponse.json(sessionJson())
          : fnp.MockResponse.failure(const fnp.ConnectionException()),
    );
    await openLogin(tester);

    await fillAndSubmit(tester);
    expect(find.text(AppStrings.failureNetwork), findsOneWidget);

    reachable = true;
    await tester.tap(find.text(AppStrings.signIn));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, RouteNames.dashboard);
  });

  testWidgets('shows a spinner and locks the form while signing in', (
    tester,
  ) async {
    final response = Completer<fnp.MockResponse>();
    di.adapter.onPost(
      TestNetwork.path('auth/login'),
      (call) => response.future,
    );
    await openLogin(tester);

    await tester.enterText(
      textFieldLabelled(AppStrings.emailLabel),
      'ada@example.com',
    );
    await tester.enterText(
      textFieldLabelled(AppStrings.passwordLabel),
      'Password1',
    );
    await tester.tap(find.text(AppStrings.signIn));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.signIn), findsNothing);
    expect(isFieldEnabled(tester, AppStrings.emailLabel), isFalse);
    expect(isFieldEnabled(tester, AppStrings.passwordLabel), isFalse);

    response.complete(fnp.MockResponse.json(sessionJson()));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, RouteNames.dashboard);
  });

  testWidgets('signing in stores the session and opens the dashboard', (
    tester,
  ) async {
    stubLogin(() => fnp.MockResponse.json(sessionJson()));
    await openLogin(tester);

    await fillAndSubmit(tester);

    expect(Get.currentRoute, RouteNames.dashboard);
    final session = Get.find<SessionController>();
    expect(session.user?.email, 'ada@example.com');
    expect((await di.tokens.read())?.accessToken, 'access-1');
    final body = di.adapter.callsTo('/v1/auth/login').single.bodyJson;
    expect(body, <String, Object?>{
      'email': 'ada@example.com',
      'password': 'Password1',
    });
  });

  testWidgets('pressing done on the password field submits', (tester) async {
    stubLogin(() => fnp.MockResponse.json(sessionJson()));
    await openLogin(tester);

    await tester.enterText(
      textFieldLabelled(AppStrings.emailLabel),
      'ada@example.com',
    );
    await tester.enterText(
      textFieldLabelled(AppStrings.passwordLabel),
      'Password1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, RouteNames.dashboard);
  });

  testWidgets('the password can be revealed', (tester) async {
    await openLogin(tester);
    bool obscured() => tester
        .widget<TextField>(textFieldLabelled(AppStrings.passwordLabel))
        .obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip(AppStrings.showPassword));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('links to registration', (tester) async {
    await openLogin(tester);

    await tester.tap(find.text(AppStrings.goToRegister));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.registerTitle), findsOneWidget);
  });

  testWidgets('tells the user when their session expired', (tester) async {
    Get.find<SessionController>().sessionExpired = true;
    await openLogin(tester);

    expect(find.text(AppStrings.failureAuthentication), findsOneWidget);
    expect(Get.find<SessionController>().sessionExpired, isFalse);
  });

  group('layout', () {
    testWidgets('fits a small phone at large text', (tester) async {
      await openLogin(tester, size: const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.signIn), findsOneWidget);
    });

    testWidgets('is a centred card on wide screens', (tester) async {
      await openLogin(tester, size: TestScreens.desktop);

      final width = tester.getSize(find.byType(Card).first).width;
      expect(width, lessThanOrEqualTo(AppSizes.authCardWidth));
      final center = tester.getCenter(find.byType(Card).first).dx;
      expect(center, closeTo(TestScreens.desktop.width / 2, 1));
    });

    testWidgets('has no card on phones', (tester) async {
      await openLogin(tester, size: TestScreens.phone);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('buttons meet the minimum touch target', (tester) async {
      await openLogin(tester);
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    });
  });
}
