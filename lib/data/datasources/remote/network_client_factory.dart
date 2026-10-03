import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../core/config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import 'auth_token_refresher.dart';
import 'network_logger_adapter.dart';

/// Builds the app's single `NetworkClient`.
///
/// Every capability comes from `flutter_network_plus`: token refresh, retries,
/// response caching, the offline queue and SSL pinning. This factory only
/// wires them to the app's configuration. Tests call it with a mock adapter
/// and in-memory stores so they run the same wiring as production.
abstract final class NetworkClientFactory {
  /// How long a cached response counts as fresh.
  static const Duration cacheTtl = Duration(minutes: 5);

  /// Creates the client.
  ///
  /// [onAuthFailure] runs once when a token refresh fails for good.
  /// [interceptors] run before the package's own ones. [onReplayed] and
  /// [onDropped] report the fate of queued offline writes.
  /// [adapter] replaces the real transport and is meant for tests only.
  /// [retryPolicy] defaults to the package's policy.
  static fnp.NetworkClient create({
    required AppConfig config,
    required fnp.TokenStorage tokenStorage,
    required AuthTokenRefresher refresher,
    required fnp.CacheStore cacheStore,
    required fnp.OfflineQueueStore offlineQueueStore,
    required fnp.ConnectivityMonitor connectivity,
    required AppLogger logger,
    required void Function() onAuthFailure,
    List<fnp.Interceptor> interceptors = const <fnp.Interceptor>[],
    void Function(fnp.QueuedRequest, fnp.NetworkResponse<Object?>)? onReplayed,
    void Function(fnp.QueuedRequest, fnp.DropReason)? onDropped,
    fnp.HttpClientAdapter? adapter,
    fnp.RetryPolicy retryPolicy = const fnp.RetryPolicy(),
  }) {
    return fnp.NetworkClient(
      environments: fnp.EnvironmentRegistry.single(
        fnp.NetworkEnvironment(
          name: config.environment.name,
          baseUrl: config.apiBaseUrl,
        ),
      ),
      adapter: adapter,
      interceptors: interceptors,
      retryPolicy: retryPolicy,
      auth: fnp.AuthConfig(
        storage: tokenStorage,
        refresher: refresher.call,
        onAuthFailure: onAuthFailure,
      ),
      cache: fnp.CacheConfig(store: cacheStore, defaultTtl: cacheTtl),
      offline: fnp.OfflineConfig(
        store: offlineQueueStore,
        connectivity: connectivity,
        onReplayed: onReplayed,
        onDropped: onDropped,
      ),
      sslPinning: config.sslPins.isEmpty
          ? null
          : fnp.SslPinningConfig(spkiSha256Pins: config.sslPins),
      logger: config.enableHttpLogging
          ? NetworkLoggerAdapter(logger)
          : const fnp.SilentNetworkLogger(),
    );
  }
}
