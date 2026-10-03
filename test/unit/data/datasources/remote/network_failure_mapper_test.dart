import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/network_failure_mapper.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Failure map(fnp.NetworkException exception) =>
      NetworkFailureMapper.map(exception);

  group('transport errors', () {
    test('connection errors become NetworkFailure', () {
      expect(map(const fnp.ConnectionException()), isA<NetworkFailure>());
    });

    test('circuit open and pinning errors become NetworkFailure', () {
      expect(
        map(const fnp.CircuitOpenException(retryAfter: Duration(seconds: 1))),
        isA<NetworkFailure>(),
      );
      expect(
        map(const fnp.CertificatePinningException(host: 'api.example.com')),
        isA<NetworkFailure>(),
      );
    });

    test('timeouts become TimeoutFailure', () {
      final failure = map(
        const fnp.NetworkTimeoutException(
          phase: fnp.TimeoutPhase.total,
          timeout: Duration(seconds: 5),
        ),
      );
      expect(failure, isA<TimeoutFailure>());
    });

    test('offline and cache miss become OfflineFailure', () {
      expect(map(const fnp.OfflineException()), isA<OfflineFailure>());
      expect(map(const fnp.CacheMissException()), isA<OfflineFailure>());
    });
  });

  group('http status errors', () {
    test('401 becomes AuthenticationFailure', () {
      expect(
        map(const fnp.UnauthorizedException()),
        isA<AuthenticationFailure>(),
      );
    });

    test('a plain 401 status also becomes AuthenticationFailure', () {
      expect(
        map(const fnp.HttpStatusException(statusCode: 401)),
        isA<AuthenticationFailure>(),
      );
    });

    test('403 becomes ForbiddenFailure', () {
      expect(
        map(const fnp.HttpStatusException(statusCode: 403)),
        isA<ForbiddenFailure>(),
      );
    });

    test('404 becomes NotFoundFailure', () {
      expect(
        map(const fnp.HttpStatusException(statusCode: 404)),
        isA<NotFoundFailure>(),
      );
    });

    test('422 becomes ValidationFailure with field errors', () {
      final failure = map(
        const fnp.HttpStatusException(
          statusCode: 422,
          decodedBody: <String, Object?>{
            'error': <String, Object?>{
              'code': 'validation_failed',
              'fields': <String, Object?>{'title': 'Required', 'bad': 3},
            },
          },
        ),
      );
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, <String, String>{
        'title': 'Required',
      });
    });

    test('validation with a malformed body has no field errors', () {
      final failure = map(
        const fnp.HttpStatusException(statusCode: 400, decodedBody: 'oops'),
      );
      expect((failure as ValidationFailure).fieldErrors, isEmpty);
    });

    test('5xx becomes ServerFailure carrying the status', () {
      final failure = map(const fnp.HttpStatusException(statusCode: 503));
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 503);
    });

    test('other 4xx becomes UnknownFailure', () {
      expect(
        map(const fnp.HttpStatusException(statusCode: 418)),
        isA<UnknownFailure>(),
      );
    });
  });

  group('other errors', () {
    test('decoding errors become ParsingFailure', () {
      expect(map(const fnp.DecodingException()), isA<ParsingFailure>());
    });

    test('cancellation and unknown errors become UnknownFailure', () {
      expect(map(const fnp.CancelledException()), isA<UnknownFailure>());
      expect(map(const fnp.UnknownNetworkException()), isA<UnknownFailure>());
    });

    test('queued-for-sync is detected and is not treated as an error type', () {
      expect(
        NetworkFailureMapper.isQueuedForSync(
          const fnp.QueuedForSyncException(),
        ),
        isTrue,
      );
      expect(
        NetworkFailureMapper.isQueuedForSync(const fnp.ConnectionException()),
        isFalse,
      );
    });
  });

  test('failure messages never expose the raw exception text', () {
    const exception = fnp.ConnectionException(
      message: 'SocketException: 10.0.0.1',
    );
    final failure = map(exception);
    expect(failure.message, isNot(contains('SocketException')));
    expect(failure.cause, same(exception));
  });
}
