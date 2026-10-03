import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'app_logger.dart';
import 'log_redactor.dart';

/// Writes redacted, single-line log entries to a text sink.
///
/// Development builds log everything; production builds only log warnings
/// and errors. Every message, context value and error text passes through
/// [LogRedactor] before reaching the sink.
class ConsoleAppLogger implements AppLogger {
  /// Creates a logger that emits entries at or above [minLevel].
  ///
  /// [sink] defaults to [debugPrint]; tests pass a collector.
  ConsoleAppLogger({
    this.minLevel = LogLevel.debug,
    this.redactor = const LogRedactor(),
    void Function(String line)? sink,
  }) : _sink = sink ?? _printLine;

  /// Creates the logger appropriate for [config]'s environment.
  factory ConsoleAppLogger.forConfig(AppConfig config) => ConsoleAppLogger(
    minLevel: config.environment.isProduction
        ? LogLevel.warning
        : LogLevel.debug,
  );

  /// Lowest severity that is written.
  final LogLevel minLevel;

  /// Removes sensitive data from every entry.
  final LogRedactor redactor;

  final void Function(String line) _sink;

  static void _printLine(String line) => debugPrint(line);

  @override
  void log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    final buffer = StringBuffer()
      ..write('[${level.name.toUpperCase()}] [$tag] ')
      ..write(redactor.redactText(message));
    if (context.isNotEmpty) {
      buffer.write(' ${redactor.redactValue(context)}');
    }
    if (error != null) {
      buffer.write(' error=${redactor.redactText('$error')}');
    }
    _sink(buffer.toString());
    if (stackTrace != null && level == LogLevel.error) {
      _sink(redactor.redactText('$stackTrace'));
    }
  }
}
