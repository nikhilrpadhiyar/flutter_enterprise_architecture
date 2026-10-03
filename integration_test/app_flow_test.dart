import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/app.dart';
import 'package:flutter_enterprise_architecture/core/config/app_config.dart';
import 'package:flutter_enterprise_architecture/core/config/app_environment.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/di/get_di.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/user_journey.dart';
import '../tool/mock_server/mock_api_server.dart';
import '../tool/mock_server/seed_data.dart';

/// Runs the full user journey on a real device or desktop window.
///
/// The mock API server runs inside the test process and the app talks to it
/// over real HTTP on the loopback interface, so nothing outside the machine is
/// needed. Storage that would need a signed app (the secure keychain) and the
/// on-disk database are replaced by in-memory versions.
///
///     flutter test integration_test -d macos
///     flutter test integration_test -d <android emulator id>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in, create, view, update and sign out', (tester) async {
    final server = MockApiServer();
    await server.start(port: 0);
    final tokens = fnp.InMemoryTokenStorage();
    await GetDI.reset();
    await GetDI.init(
      config: AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: server.baseUrl,
      ),
      overrides: GetDIOverrides(
        logger: ConsoleAppLogger(sink: (_) {}),
        database: AppDatabase(NativeDatabase.memory()),
        tokenStorage: tokens,
        cacheStore: fnp.MemoryCacheStore(),
        offlineQueueStore: fnp.InMemoryOfflineQueueStore(),
        connectivity: fnp.FakeConnectivityMonitor(),
      ),
    );

    try {
      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      await runUserJourney(
        tester,
        settle: () => _settle(tester),
        email: demoEmail,
        password: demoPassword,
        projectName: 'Platform migration',
      );

      expect(await tokens.read(), isNull);
      expect(Get.currentRoute, '/login');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await GetDI.reset();
      await server.stop();
    }
  });
}

/// Lets real network and database work finish while frames are drawn.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
