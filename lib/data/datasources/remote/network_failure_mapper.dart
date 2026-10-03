import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../core/error/failure.dart';

/// Translates `flutter_network_plus` exceptions into app [Failure]s.
///
/// This is the single place where package exceptions are interpreted, so the
/// rest of the app never depends on them. It lives in the data layer because
/// only data sources may import the networking package.
abstract final class NetworkFailureMapper {
  static const int _badRequest = 400;
  static const int _unauthorized = 401;
  static const int _forbidden = 403;
  static const int _notFound = 404;
  static const int _unprocessable = 422;
  static const int _serverErrorStart = 500;

  /// Maps [exception] to the closest [Failure].
  static Failure map(fnp.NetworkException exception) {
    return switch (exception) {
      fnp.QueuedForSyncException() => OfflineFailure(cause: exception),
      fnp.OfflineException() => OfflineFailure(cause: exception),
      fnp.ConnectionException() => NetworkFailure(cause: exception),
      fnp.CircuitOpenException() => NetworkFailure(cause: exception),
      fnp.CertificatePinningException() => NetworkFailure(cause: exception),
      fnp.NetworkTimeoutException() => TimeoutFailure(cause: exception),
      fnp.UnauthorizedException() => AuthenticationFailure(cause: exception),
      fnp.HttpStatusException() => _mapStatus(exception),
      fnp.DecodingException() => ParsingFailure(cause: exception),
      fnp.CacheMissException() => OfflineFailure(cause: exception),
      fnp.CancelledException() => UnknownFailure(cause: exception),
      fnp.UnknownNetworkException() => UnknownFailure(cause: exception),
    };
  }

  /// Whether [exception] means the request was accepted into the offline
  /// queue and will be sent later, which is not an error.
  static bool isQueuedForSync(fnp.NetworkException exception) =>
      exception is fnp.QueuedForSyncException;

  static Failure _mapStatus(fnp.HttpStatusException exception) {
    final status = exception.statusCode;
    if (status == _unauthorized) return AuthenticationFailure(cause: exception);
    if (status == _forbidden) return ForbiddenFailure(cause: exception);
    if (status == _notFound) return NotFoundFailure(cause: exception);
    if (status == _badRequest || status == _unprocessable) {
      return ValidationFailure(
        fieldErrors: _fieldErrors(exception.decodedBody),
        cause: exception,
      );
    }
    if (status >= _serverErrorStart) {
      return ServerFailure(statusCode: status, cause: exception);
    }
    return UnknownFailure(cause: exception);
  }

  /// Reads `error.fields` from the API error envelope, ignoring bad shapes.
  static Map<String, String> _fieldErrors(Object? body) {
    if (body is! Map<String, Object?>) return const <String, String>{};
    final error = body['error'];
    if (error is! Map<String, Object?>) return const <String, String>{};
    final fields = error['fields'];
    if (fields is! Map<String, Object?>) return const <String, String>{};
    return <String, String>{
      for (final entry in fields.entries)
        if (entry.value is String) entry.key: entry.value! as String,
    };
  }
}
