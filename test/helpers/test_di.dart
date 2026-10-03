import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/core/messaging/app_messenger.dart';
import 'package:flutter_enterprise_architecture/core/routes/app_routes.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_theme.dart';
import 'package:flutter_enterprise_architecture/di/get_di.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_enterprise_architecture/features/settings/controllers/theme_controller.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'domain_fixtures.dart';
import 'sequential_ids.dart';
import 'test_database.dart';
import 'test_network.dart';

/// A fully wired dependency graph for tests.
///
/// It uses the production `GetDI.init` with in-memory storage, a scriptable
/// connectivity monitor and a mock HTTP transport, so tests never touch the
/// device or the network and never depend on production state. Call
/// [dispose] in `tearDown` to reset GetX between tests.
class TestDi {
  TestDi._();

  final fnp.MockHttpClientAdapter adapter = fnp.MockHttpClientAdapter();
  final fnp.InMemoryTokenStorage tokens = fnp.InMemoryTokenStorage();
  final fnp.FakeConnectivityMonitor connectivity =
      fnp.FakeConnectivityMonitor();

  /// Messages the app asked to show, oldest first.
  final RecordingMessenger messenger = RecordingMessenger();

  /// Builds the graph.
  static Future<TestDi> create() async {
    await GetDI.reset();
    final di = TestDi._();
    await GetDI.init(
      config: TestNetwork.config,
      overrides: GetDIOverrides(
        logger: ConsoleAppLogger(sink: (_) {}),
        ids: SequentialIds(),
        messenger: di.messenger,
        database: createTestDatabase(),
        tokenStorage: di.tokens,
        cacheStore: fnp.MemoryCacheStore(),
        offlineQueueStore: fnp.InMemoryOfflineQueueStore(),
        connectivity: di.connectivity,
        adapter: di.adapter,
        retryPolicy: const fnp.RetryPolicy.none(),
      ),
    );
    return di;
  }

  /// Stores a valid session token.
  Future<void> signIn() => tokens.write(
    fnp.AuthTokenPair(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );

  /// Signs in: stores a valid token and records the user in the session, so
  /// routes behind the auth guard open.
  Future<void> signInUser() async {
    await signIn();
    Get.find<SessionController>().setUser(buildUser());
  }

  /// Releases everything registered with GetX.
  Future<void> dispose() => GetDI.reset();
}

/// A routed app using the real route table plus stand-in pages.
Widget buildTestApp({
  String initialRoute = RouteNames.splash,
  List<GetPage<dynamic>> extraPages = const <GetPage<dynamic>>[],
}) {
  return GetMaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: Get.find<ThemeController>().themeMode,
    initialRoute: initialRoute,
    getPages: <GetPage<dynamic>>[...AppRoutes.pages, ...extraPages],
    unknownRoute: AppRoutes.unknown,
  );
}

/// A page that shows only [label], to assert which route is open.
GetPage<dynamic> markerPage(
  String name,
  String label, {
  List<GetMiddleware>? middlewares,
}) {
  return GetPage<dynamic>(
    name: name,
    middlewares: middlewares,
    page: () => Scaffold(body: Text(label)),
  );
}

/// Opens the real app at [route] and waits for it to settle.
Future<void> openRoute(
  WidgetTester tester,
  String route, {
  Size size = const Size(390, 844),
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() async {
    // Unmount the pages first so their controllers cancel their streams;
    // otherwise shutting down the network client waits on them forever.
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    buildTestApp(initialRoute: route, extraPages: <GetPage<dynamic>>[]),
  );
  if (settle) await settleApp(tester);
}

/// Waits for the app to finish loading and animating.
///
/// The database and queue live outside the test's fake clock, so their
/// results only arrive while real time passes, while timers inside the app
/// only fire when the fake clock advances. Alternating between the two lets
/// chains that need both finish. It pumps for a bounded time rather than
/// until idle, because a progress bar that is spinning never goes idle. Use
/// instead of `pumpAndSettle` after data operations.
Future<void> settleApp(WidgetTester tester) async {
  for (var round = 0; round < 4; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }
}

/// An [AppMessenger] that remembers what it was asked to show.
class RecordingMessenger implements AppMessenger {
  /// Messages shown so far, oldest first.
  final List<String> messages = <String>[];

  @override
  void show(String message) => messages.add(message);
}
