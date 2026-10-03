import 'app_environment.dart';

/// Immutable, typed application configuration.
///
/// Values are injected at build time with
/// `--dart-define-from-file=env/<environment>.json`, so no environment
/// specific value is hardcoded in source. This is the only class that reads
/// compile-time environment values.
class AppConfig {
  /// Creates a configuration with explicit values (used by tests).
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.sslPins = const <String>{},
    this.enableHttpLogging = false,
  });

  /// Builds the configuration from `--dart-define` values.
  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      _envNameKey,
      defaultValue: 'development',
    );
    const baseUrl = String.fromEnvironment(_baseUrlKey);
    const pins = String.fromEnvironment(_sslPinsKey);
    const httpLogging = bool.fromEnvironment(_httpLoggingKey);

    final config = AppConfig(
      environment: AppEnvironment.parse(environmentName),
      apiBaseUrl: baseUrl,
      sslPins: pins.isEmpty
          ? const <String>{}
          : pins.split(',').map((pin) => pin.trim()).toSet(),
      enableHttpLogging: httpLogging,
    );
    config.validate();
    return config;
  }

  static const String _envNameKey = 'ENV_NAME';
  static const String _baseUrlKey = 'API_BASE_URL';
  static const String _sslPinsKey = 'SSL_PINS';
  static const String _httpLoggingKey = 'ENABLE_HTTP_LOGGING';

  /// Active deployment environment.
  final AppEnvironment environment;

  /// Base URL of the REST API. Must use HTTPS.
  final String apiBaseUrl;

  /// Optional SPKI SHA-256 pins used for SSL pinning.
  final Set<String> sslPins;

  /// Whether request and response logging is enabled.
  final bool enableHttpLogging;

  /// Throws a [StateError] when the configuration is unusable.
  void validate() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasAuthority) {
      throw StateError(
        'API_BASE_URL is missing. Run with '
        '--dart-define-from-file=env/<environment>.json',
      );
    }
    if (environment.isProduction && uri.scheme != 'https') {
      throw StateError('Production API_BASE_URL must use HTTPS.');
    }
  }
}
