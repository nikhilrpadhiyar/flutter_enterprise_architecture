import '../constants/app_strings.dart';

/// Base type of every error that crosses a layer boundary.
///
/// Data sources and repositories translate low level exceptions into a
/// [Failure]; use cases and controllers only ever see this hierarchy. The
/// [message] is safe to show to users and never contains raw exception text.
/// The sealed hierarchy lets callers switch exhaustively.
sealed class Failure implements Exception {
  /// Creates a failure with a user-safe [message] and an optional [cause]
  /// kept for logging only.
  const Failure(this.message, {this.cause});

  /// User-friendly description of what went wrong.
  final String message;

  /// The underlying error, for diagnostics. Never shown to users.
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// The server could not be reached.
final class NetworkFailure extends Failure {
  /// Creates a network failure.
  const NetworkFailure({
    String message = AppStrings.failureNetwork,
    super.cause,
  }) : super(message);
}

/// The device is offline and nothing can be served locally.
final class OfflineFailure extends Failure {
  /// Creates an offline failure.
  const OfflineFailure({
    String message = AppStrings.failureOffline,
    super.cause,
  }) : super(message);
}

/// A request exceeded its time limit.
final class TimeoutFailure extends Failure {
  /// Creates a timeout failure.
  const TimeoutFailure({
    String message = AppStrings.failureTimeout,
    super.cause,
  }) : super(message);
}

/// The session is missing, invalid or could not be refreshed.
final class AuthenticationFailure extends Failure {
  /// Creates an authentication failure.
  const AuthenticationFailure({
    String message = AppStrings.failureAuthentication,
    super.cause,
  }) : super(message);
}

/// The user is not allowed to perform the action.
final class ForbiddenFailure extends Failure {
  /// Creates a forbidden failure.
  const ForbiddenFailure({
    String message = AppStrings.failureForbidden,
    super.cause,
  }) : super(message);
}

/// The requested resource does not exist.
final class NotFoundFailure extends Failure {
  /// Creates a not-found failure.
  const NotFoundFailure({
    String message = AppStrings.failureNotFound,
    super.cause,
  }) : super(message);
}

/// Submitted data was rejected, locally or by the server.
final class ValidationFailure extends Failure {
  /// Creates a validation failure with optional per-field messages keyed by
  /// the request field name.
  const ValidationFailure({
    String message = AppStrings.failureValidation,
    this.fieldErrors = const <String, String>{},
    super.cause,
  }) : super(message);

  /// Field-level error messages, keyed by field name.
  final Map<String, String> fieldErrors;
}

/// The server failed to process a valid request.
final class ServerFailure extends Failure {
  /// Creates a server failure, optionally recording the HTTP [statusCode].
  const ServerFailure({
    String message = AppStrings.failureServer,
    this.statusCode,
    super.cause,
  }) : super(message);

  /// HTTP status code returned by the server, when known.
  final int? statusCode;
}

/// A response could not be decoded into the expected shape.
final class ParsingFailure extends Failure {
  /// Creates a parsing failure.
  const ParsingFailure({
    String message = AppStrings.failureParsing,
    super.cause,
  }) : super(message);
}

/// Local persistence failed.
final class CacheFailure extends Failure {
  /// Creates a cache failure.
  const CacheFailure({String message = AppStrings.failureCache, super.cause})
    : super(message);
}

/// A failure that does not match any other category.
final class UnknownFailure extends Failure {
  /// Creates an unknown failure.
  const UnknownFailure({
    String message = AppStrings.failureUnknown,
    super.cause,
  }) : super(message);
}
