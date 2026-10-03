import 'package:flutter_enterprise_architecture/core/logging/log_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const redactor = LogRedactor();

  group('isSensitiveKey', () {
    test('flags credentials and personal data', () {
      for (final key in [
        'password',
        'Authorization',
        'accessToken',
        'refresh_token',
        'idToken',
        'client-secret',
        'apiKey',
        'email',
        'phone',
        'Set-Cookie',
      ]) {
        expect(redactor.isSensitiveKey(key), isTrue, reason: key);
      }
    });

    test('leaves ordinary keys alone', () {
      for (final key in ['title', 'status', 'page', 'id']) {
        expect(redactor.isSensitiveKey(key), isFalse, reason: key);
      }
    });
  });

  group('redactValue', () {
    test('masks sensitive entries recursively', () {
      final result = redactor.redactValue(<String, Object?>{
        'title': 'Ship it',
        'password': 'hunter2',
        'user': <String, Object?>{'email': 'a@b.com', 'name': 'Ada'},
        'items': <Object?>[
          <String, Object?>{'accessToken': 'abc'},
        ],
      });
      expect(result, <String, Object?>{
        'title': 'Ship it',
        'password': '***',
        'user': <String, Object?>{'email': '***', 'name': 'Ada'},
        'items': <Object?>[
          <String, Object?>{'accessToken': '***'},
        ],
      });
    });

    test('passes through non-collection values', () {
      expect(redactor.redactValue(42), 42);
      expect(redactor.redactValue(null), isNull);
    });
  });

  group('redactText', () {
    test('masks bearer tokens', () {
      final result = redactor.redactText('Authorization: Bearer abc.def-123');
      expect(result, isNot(contains('abc.def-123')));
    });

    test('masks key value pairs in json and query strings', () {
      final json = redactor.redactText('{"password":"hunter2","id":"7"}');
      expect(json, isNot(contains('hunter2')));
      expect(json, contains('"id":"7"'));

      final query = redactor.redactText('login?email=a@b.com&page=2');
      expect(query, isNot(contains('a@b.com')));
      expect(query, contains('page=2'));

      final token = redactor.redactText('refreshToken: xyz123');
      expect(token, isNot(contains('xyz123')));
    });

    test('leaves harmless text unchanged', () {
      expect(redactor.redactText('Loaded 12 tasks'), 'Loaded 12 tasks');
    });
  });
}
