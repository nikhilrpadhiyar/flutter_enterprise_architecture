/// Runs the mock API locally.
///
///     dart run tool/mock_server/main.dart [--port 8080] [--token-seconds 900]
///         [--delay-ms 0]
library;

import 'dart:io';

import 'mock_api_server.dart';
import 'seed_data.dart';

Future<void> main(List<String> args) async {
  int option(String name, int fallback) {
    final index = args.indexOf('--$name');
    if (index == -1 || index + 1 >= args.length) return fallback;
    return int.tryParse(args[index + 1]) ?? fallback;
  }

  final server = MockApiServer(
    accessTokenLifetime: Duration(seconds: option('token-seconds', 900)),
    artificialDelay: Duration(milliseconds: option('delay-ms', 0)),
  );
  await server.start(port: option('port', 8080));
  stdout
    ..writeln('Mock API listening on ${server.baseUrl}')
    ..writeln('Sign in with $demoEmail / $demoPassword')
    ..writeln('Android emulator: use http://10.0.2.2:${server.port}/v1');
  await ProcessSignal.sigint.watch().first;
  await server.stop();
}
