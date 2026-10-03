import 'package:flutter_enterprise_architecture/core/config/app_config.dart';
import 'package:flutter_enterprise_architecture/core/config/app_environment.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/session_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/user_data_cleaner.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/auth_token_refresher.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/network_client_factory.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/remote_requester.dart';
import 'package:flutter_enterprise_architecture/data/session/session_expiry_notifier.dart';
import 'package:flutter_enterprise_architecture/data/sync/offline_sync_handler.dart';
import 'package:flutter_enterprise_architecture/data/sync/queued_request_guard.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import 'test_database.dart';

/// A real `NetworkClient` and local database wired like production, with a
/// mock transport and in-memory stores so tests run the full pipeline
/// without a device or network. Call [dispose] in `tearDown`.
class TestNetwork {
  TestNetwork({DateTime Function()? clock}) {
    clock ??= DateTime.now;
    this.clock = clock;
    database = createTestDatabase();
    taskLocal = TaskLocalDataSourceImpl(database);
    sessionLocal = SessionLocalDataSourceImpl(database);
    responseCache = fnp.MemoryCacheStore();
    cleaner = LocalUserDataCleaner(taskLocal, sessionLocal, responseCache);
    syncHandler = OfflineSyncHandler(taskLocal, logger, clock: clock);
    client = NetworkClientFactory.create(
      config: config,
      tokenStorage: tokens,
      refresher: AuthTokenRefresher(clock: clock),
      cacheStore: responseCache,
      offlineQueueStore: queueStore,
      connectivity: connectivity,
      logger: logger,
      onAuthFailure: expiry.notify,
      interceptors: <fnp.Interceptor>[QueuedRequestGuard(taskLocal)],
      onReplayed: syncHandler.onReplayed,
      onDropped: syncHandler.onDropped,
      adapter: adapter,
      retryPolicy: const fnp.RetryPolicy.none(),
    );
    requester = RemoteRequester(client, logger);
  }

  static const AppConfig config = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'https://api.example.com/v1',
  );

  final fnp.MockHttpClientAdapter adapter = fnp.MockHttpClientAdapter();
  final fnp.InMemoryTokenStorage tokens = fnp.InMemoryTokenStorage();
  final fnp.InMemoryOfflineQueueStore queueStore =
      fnp.InMemoryOfflineQueueStore();
  final fnp.FakeConnectivityMonitor connectivity =
      fnp.FakeConnectivityMonitor();
  final SessionExpiryNotifier expiry = SessionExpiryNotifier();
  final List<String> logLines = <String>[];
  late final ConsoleAppLogger logger = ConsoleAppLogger(sink: logLines.add);
  late final DateTime Function() clock;
  late final AppDatabase database;
  late final TaskLocalDataSourceImpl taskLocal;
  late final SessionLocalDataSourceImpl sessionLocal;
  late final fnp.MemoryCacheStore responseCache;
  late final LocalUserDataCleaner cleaner;
  late final OfflineSyncHandler syncHandler;
  late final fnp.NetworkClient client;
  late final RemoteRequester requester;

  /// Signs in by storing a valid token pair.
  Future<void> signIn({Duration validFor = const Duration(hours: 1)}) {
    return tokens.write(
      fnp.AuthTokenPair(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: clock().add(validFor),
      ),
    );
  }

  /// Waits until the offline queue is empty and the local database reflects
  /// every delivered change.
  Future<void> settleQueue() async {
    final queue = client.offlineQueue!;
    if (queue.pending > 0) {
      await queue.pendingChanges
          .firstWhere((count) => count == 0)
          .timeout(const Duration(seconds: 5));
    }
    await Future<void>.delayed(Duration.zero);
    await syncHandler.idle;
  }

  /// Releases the database.
  Future<void> dispose() => database.close();

  /// Matches request paths ending in [suffix] (the base path is `/v1`).
  static RegExp path(String suffix) => RegExp('/v1/$suffix\$');
}
