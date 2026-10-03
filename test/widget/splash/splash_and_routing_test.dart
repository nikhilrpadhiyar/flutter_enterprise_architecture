import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/routes/auth_middleware.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/data/session/session_expiry_notifier.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/json_fixtures.dart';
import '../../helpers/test_di.dart';
import '../../helpers/test_network.dart';

void main() {
  late TestDi di;

  setUp(() async => di = await TestDi.create());
  tearDown(() => di.dispose());

  Widget app({String initial = RouteNames.splash}) => buildTestApp(
    initialRoute: initial,
    extraPages: <GetPage<dynamic>>[
      markerPage(
        '/secret',
        'secret-page',
        middlewares: <GetMiddleware>[AuthMiddleware()],
      ),
    ],
  );

  group('splash', () {
    testWidgets('shows the loading state first', (tester) async {
      final completer = Completer<fnp.MockResponse>();
      await di.signIn();
      di.adapter.onGet(TestNetwork.path('profile'), (call) => completer.future);

      await tester.pumpWidget(app());
      await tester.pump();

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(fnp.MockResponse.json(userJson()));
      await tester.pumpAndSettle();
    });

    testWidgets('opens sign in when there is no saved session', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.signInTitle), findsOneWidget);
      expect(Get.find<SessionController>().isSignedIn, isFalse);
      expect(di.adapter.capturedRequests, isEmpty);
    });

    testWidgets('opens the dashboard when the session is restored', (
      tester,
    ) async {
      await di.signIn();
      di.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.json(userJson()),
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(Get.currentRoute, RouteNames.dashboard);
      expect(Get.find<SessionController>().user?.name, 'Ada Lovelace');
    });

    testWidgets('shows an error with retry when restoration fails', (
      tester,
    ) async {
      await di.signIn();
      var reachable = false;
      di.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => reachable
            ? fnp.MockResponse.json(userJson())
            : fnp.MockResponse.failure(const fnp.ConnectionException()),
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.failureNetwork), findsOneWidget);
      expect(Get.currentRoute, isNot(RouteNames.dashboard));

      reachable = true;
      await tester.tap(find.text(AppStrings.tryAgain));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, RouteNames.dashboard);
    });
  });

  group('session handling', () {
    testWidgets('an expired session returns to sign in and sets a notice', (
      tester,
    ) async {
      await di.signIn();
      di.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.json(userJson()),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(Get.currentRoute, RouteNames.dashboard);

      di.adapter.onPost(
        TestNetwork.path('auth/refresh'),
        (call) =>
            fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401),
      );
      await di.tokens.write(
        fnp.AuthTokenPair(
          accessToken: 'old',
          refreshToken: 'stale',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      di.adapter.onGet(
        TestNetwork.path('projects'),
        (call) => fnp.MockResponse.json(pageJson(<Object?>[])),
      );
      // Any authenticated call now fails the refresh and signs the user out.
      unawaited(
        Get.find<fnp.NetworkClient>().get<Object?>(
          'projects',
          decoder: (json) => json,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.signInTitle), findsOneWidget);
      expect(find.text(AppStrings.failureAuthentication), findsOneWidget);
      final session = Get.find<SessionController>();
      expect(session.isSignedIn, isFalse);
      expect(session.sessionExpired, isFalse);
    });

    testWidgets('signOut clears the user and returns to sign in', (
      tester,
    ) async {
      await di.signIn();
      di.adapter
        ..onGet(
          TestNetwork.path('profile'),
          (call) => fnp.MockResponse.json(userJson()),
        )
        ..onPost(
          TestNetwork.path('auth/logout'),
          (call) => fnp.MockResponse.json(<String, Object?>{}),
        );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Sign out sends waiting changes, calls the server and wipes the local
      // database before navigating, which needs real (not fake) time.
      await tester.runAsync(() async {
        unawaited(Get.find<SessionController>().signOut());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.signInTitle), findsOneWidget);
      expect(Get.find<SessionController>().isSignedIn, isFalse);
      expect(await di.tokens.read(), isNull);
    });

    testWidgets('expiry while signed out is ignored', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.signInTitle), findsOneWidget);

      Get.find<SessionExpiryNotifier>().notify();
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.signInTitle), findsOneWidget);
      expect(Get.find<SessionController>().sessionExpired, isFalse);
    });
  });

  group('routing', () {
    testWidgets('unknown routes show the not found page', (tester) async {
      await tester.pumpWidget(app(initial: '/does-not-exist'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.pageNotFoundTitle), findsOneWidget);
    });

    testWidgets('the guard redirects signed-out users to sign in', (
      tester,
    ) async {
      await tester.pumpWidget(app(initial: RouteNames.login));
      await tester.pumpAndSettle();

      unawaited(Get.toNamed<void>('/secret'));
      await tester.pumpAndSettle();

      expect(find.text('secret-page'), findsNothing);
      expect(find.text(AppStrings.signInTitle), findsOneWidget);
    });

    testWidgets('the guard lets signed-in users through', (tester) async {
      await di.signIn();
      di.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.json(userJson()),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      unawaited(Get.toNamed<void>('/secret'));
      await tester.pumpAndSettle();

      expect(find.text('secret-page'), findsOneWidget);
    });
  });
}
