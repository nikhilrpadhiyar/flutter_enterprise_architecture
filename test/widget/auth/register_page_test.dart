import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/auth_finders.dart';
import '../../helpers/json_fixtures.dart';
import '../../helpers/test_di.dart';
import '../../helpers/test_network.dart';

void main() {
  late TestDi di;

  setUp(() async => di = await TestDi.create());
  tearDown(() => di.dispose());

  Future<void> openRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        initialRoute: RouteNames.register,
        extraPages: <GetPage<dynamic>>[],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Ada Lovelace',
    String email = 'ada@example.com',
    String password = 'Password1',
    String? confirm,
  }) async {
    await tester.enterText(textFieldLabelled(AppStrings.nameLabel), name);
    await tester.enterText(textFieldLabelled(AppStrings.emailLabel), email);
    await tester.enterText(
      textFieldLabelled(AppStrings.passwordLabel),
      password,
    );
    await tester.enterText(
      textFieldLabelled(AppStrings.confirmPasswordLabel),
      confirm ?? password,
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text(AppStrings.createAccount));
    await tester.tap(find.text(AppStrings.createAccount));
    await tester.pumpAndSettle();
  }

  testWidgets('shows every field from the wireframe', (tester) async {
    await openRegister(tester);

    expect(find.text(AppStrings.registerTitle), findsOneWidget);
    for (final label in <String>[
      AppStrings.nameLabel,
      AppStrings.emailLabel,
      AppStrings.passwordLabel,
      AppStrings.confirmPasswordLabel,
    ]) {
      expect(textFieldLabelled(label), findsOneWidget, reason: label);
    }
    expect(find.text(AppStrings.createAccount), findsOneWidget);
    expect(find.text(AppStrings.goToSignIn), findsOneWidget);
  });

  testWidgets('empty submit lists every problem and sends nothing', (
    tester,
  ) async {
    await openRegister(tester);

    await submit(tester);

    expect(find.text(AppStrings.requiredField), findsNWidgets(3));
    expect(di.adapter.capturedRequests, isEmpty);
  });

  testWidgets('mismatching passwords are reported', (tester) async {
    await openRegister(tester);

    await fill(tester, confirm: 'Different1');
    await submit(tester);

    expect(find.text(AppStrings.passwordsDoNotMatch), findsOneWidget);
    expect(di.adapter.capturedRequests, isEmpty);
  });

  testWidgets('a weak password is reported', (tester) async {
    await openRegister(tester);

    await fill(tester, password: 'weak');
    await submit(tester);

    expect(find.text(AppStrings.weakPassword), findsOneWidget);
  });

  testWidgets('a taken email is reported on the email field', (tester) async {
    di.adapter.onPost(
      TestNetwork.path('auth/register'),
      (call) => fnp.MockResponse.json(
        errorJson(
          'validation_failed',
          fields: <String, String>{'email': 'Email is already registered'},
        ),
        statusCode: 422,
      ),
    );
    await openRegister(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text('Email is already registered'), findsOneWidget);
    expect(Get.currentRoute, isNot(RouteNames.dashboard));
  });

  testWidgets('a network failure shows a banner', (tester) async {
    di.adapter.onPost(
      TestNetwork.path('auth/register'),
      (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
    );
    await openRegister(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text(AppStrings.failureNetwork), findsOneWidget);
  });

  testWidgets('locks the form and shows a spinner while submitting', (
    tester,
  ) async {
    final response = Completer<fnp.MockResponse>();
    di.adapter.onPost(
      TestNetwork.path('auth/register'),
      (call) => response.future,
    );
    await openRegister(tester);
    await fill(tester);
    await tester.ensureVisible(find.text(AppStrings.createAccount));
    await tester.tap(find.text(AppStrings.createAccount));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(isFieldEnabled(tester, AppStrings.nameLabel), isFalse);
    expect(isFieldEnabled(tester, AppStrings.confirmPasswordLabel), isFalse);

    response.complete(fnp.MockResponse.json(sessionJson(), statusCode: 201));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, RouteNames.dashboard);
  });

  testWidgets('registering signs in and opens the dashboard', (tester) async {
    di.adapter.onPost(
      TestNetwork.path('auth/register'),
      (call) => fnp.MockResponse.json(sessionJson(), statusCode: 201),
    );
    await openRegister(tester);

    await fill(tester);
    await submit(tester);

    expect(Get.currentRoute, RouteNames.dashboard);
    expect(Get.find<SessionController>().isSignedIn, isTrue);
    expect((await di.tokens.read())?.refreshToken, 'refresh-1');
    expect(
      di.adapter.callsTo('/v1/auth/register').single.bodyJson,
      <String, Object?>{
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'password': 'Password1',
      },
    );
  });

  testWidgets('links back to sign in', (tester) async {
    await openRegister(tester);

    await tester.ensureVisible(find.text(AppStrings.goToSignIn));
    await tester.tap(find.text(AppStrings.goToSignIn));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.signInTitle), findsOneWidget);
  });
}
