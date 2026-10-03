import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';

/// A logger that discards its output, for tests that do not inspect logs.
ConsoleAppLogger silentLogger() => ConsoleAppLogger(sink: (_) {});
