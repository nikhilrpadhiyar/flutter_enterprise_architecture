import 'package:flutter_enterprise_architecture/core/config/app_config.dart';
import 'package:flutter_enterprise_architecture/core/config/app_environment.dart';
import 'package:flutter_enterprise_architecture/core/logging/app_logger.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;

  setUp(() => lines = <String>[]);

  test('writes level, tag, message and context on one line', () {
    ConsoleAppLogger(sink: lines.add).info(
      LogTag.repository,
      'loaded tasks',
      context: <String, Object?>{'count': 3},
    );
    expect(lines.single, startsWith('[INFO] [repository] loaded tasks'));
    expect(lines.single, contains('count: 3'));
  });

  test('redacts secrets in message, context and error', () {
    ConsoleAppLogger(sink: lines.add).log(
      LogLevel.error,
      LogTag.request,
      'sent Authorization: Bearer secret-token-1',
      context: <String, Object?>{'password': 'hunter2', 'id': 5},
      error: 'failed for email=a@b.com',
    );
    final output = lines.join('\n');
    for (final leaked in ['secret-token-1', 'hunter2', 'a@b.com']) {
      expect(output, isNot(contains(leaked)));
    }
    expect(output, contains('id: 5'));
  });

  test('suppresses entries below the minimum level', () {
    final logger = ConsoleAppLogger(
      minLevel: LogLevel.warning,
      sink: lines.add,
    );
    logger
      ..debug(LogTag.app, 'noisy')
      ..info(LogTag.app, 'chatty')
      ..warning(LogTag.app, 'careful');
    expect(lines, hasLength(1));
    expect(lines.single, contains('careful'));
  });

  test('forConfig is quiet in production and verbose elsewhere', () {
    const production = AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: 'https://api.example.com',
    );
    const development = AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: 'https://api.example.com',
    );
    expect(ConsoleAppLogger.forConfig(production).minLevel, LogLevel.warning);
    expect(ConsoleAppLogger.forConfig(development).minLevel, LogLevel.debug);
  });
}
