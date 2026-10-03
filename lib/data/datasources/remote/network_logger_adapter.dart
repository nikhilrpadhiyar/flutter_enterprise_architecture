import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../core/logging/app_logger.dart';

/// Routes `flutter_network_plus` log output into the app's [AppLogger].
///
/// This keeps one logging pipeline, so redaction and level filtering apply to
/// network logs as well.
class NetworkLoggerAdapter implements fnp.NetworkLogger {
  /// Creates an adapter that forwards to [_logger].
  const NetworkLoggerAdapter(this._logger);

  final AppLogger _logger;

  @override
  void log(
    fnp.NetworkLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.log(
      _level(level),
      LogTag.request,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  LogLevel _level(fnp.NetworkLogLevel level) => switch (level) {
    fnp.NetworkLogLevel.debug => LogLevel.debug,
    fnp.NetworkLogLevel.info => LogLevel.info,
    fnp.NetworkLogLevel.warning => LogLevel.warning,
    fnp.NetworkLogLevel.error => LogLevel.error,
  };
}
