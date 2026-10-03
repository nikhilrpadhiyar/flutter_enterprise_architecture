import '../../../core/error/failure.dart';

/// Runs a local storage operation and reports any failure as a
/// [CacheFailure].
///
/// Database and parsing errors are implementation details that controllers
/// must not have to know about. Failures that are already app failures pass
/// through unchanged.
Future<T> guardLocal<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on Failure {
    rethrow;
  } on Object catch (error) {
    throw CacheFailure(cause: error);
  }
}
