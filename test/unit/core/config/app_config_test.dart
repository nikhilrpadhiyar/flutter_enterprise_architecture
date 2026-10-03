import 'package:flutter_enterprise_architecture/core/config/app_config.dart';
import 'package:flutter_enterprise_architecture/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.parse', () {
    test('resolves known names case-insensitively', () {
      expect(AppEnvironment.parse('Staging'), AppEnvironment.staging);
      expect(AppEnvironment.parse('production'), AppEnvironment.production);
    });

    test('falls back to development for unknown names', () {
      expect(AppEnvironment.parse('qa'), AppEnvironment.development);
    });
  });

  group('AppConfig.validate', () {
    test('accepts an https base url', () {
      const config = AppConfig(
        environment: AppEnvironment.production,
        apiBaseUrl: 'https://api.example.com/v1',
      );
      expect(config.validate, returnsNormally);
    });

    test('rejects an empty base url', () {
      const config = AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: '',
      );
      expect(config.validate, throwsStateError);
    });

    test('rejects http in production', () {
      const config = AppConfig(
        environment: AppEnvironment.production,
        apiBaseUrl: 'http://api.example.com',
      );
      expect(config.validate, throwsStateError);
    });
  });
}
