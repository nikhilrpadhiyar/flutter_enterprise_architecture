/// Severity of a log entry, ordered from least to most severe.
enum LogLevel {
  /// Detailed diagnostics, development only.
  debug,

  /// Normal lifecycle information.
  info,

  /// A recoverable problem.
  warning,

  /// A failure that needs attention.
  error,
}

/// Well-known tags that group log entries by architectural area.
abstract final class LogTag {
  /// Outgoing requests.
  static const String request = 'request';

  /// Incoming responses.
  static const String response = 'response';

  /// Repository implementations.
  static const String repository = 'repository';

  /// Use cases.
  static const String useCase = 'usecase';

  /// Controllers.
  static const String controller = 'controller';

  /// Route changes.
  static const String navigation = 'navigation';

  /// Application start-up and dependency wiring.
  static const String app = 'app';
}

/// Centralised, structured logging contract.
///
/// Implementations must redact sensitive data before output. Nothing in the
/// app prints directly; everything goes through an [AppLogger].
abstract interface class AppLogger {
  /// Writes one entry. [tag] groups entries by area (see [LogTag]) and
  /// [context] carries structured fields.
  void log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, Object?> context,
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Convenience methods for [AppLogger].
extension AppLoggerShortcuts on AppLogger {
  /// Logs at [LogLevel.debug].
  void debug(
    String tag,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) => log(LogLevel.debug, tag, message, context: context);

  /// Logs at [LogLevel.info].
  void info(
    String tag,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) => log(LogLevel.info, tag, message, context: context);

  /// Logs at [LogLevel.warning].
  void warning(
    String tag,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
  }) => log(LogLevel.warning, tag, message, context: context, error: error);

  /// Logs at [LogLevel.error].
  void error(
    String tag,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    tag,
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );
}
