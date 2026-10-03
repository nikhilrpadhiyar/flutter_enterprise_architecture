import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../datasources/local/pending_operation_ledger.dart';

/// Stops queued requests that the signed-in user did not create.
///
/// `flutter_network_plus` keeps offline writes in a persistent queue that the
/// app cannot empty. After a sign out the local ledger is wiped, so any
/// leftover entry is rejected here instead of being sent under a different
/// account. Only replays are inspected; normal requests pass through.
class QueuedRequestGuard extends fnp.Interceptor {
  /// Creates the guard over [_ledger].
  const QueuedRequestGuard(this._ledger);

  /// The `extra` flag the networking layer sets on replayed requests.
  static const String replayedFlag = 'fnp.replayed';

  /// Header carrying the key that links a request to the ledger.
  static const String idempotencyHeader = 'idempotency-key';

  final PendingOperationLedger _ledger;

  @override
  Future<fnp.InterceptorResult> onRequest(fnp.NetworkRequest request) async {
    if (request.extra[replayedFlag] != true) {
      return fnp.InterceptorResult.next(request);
    }
    final key = idempotencyKeyOf(request.headers);
    if (key != null && await _ledger.contains(key)) {
      return fnp.InterceptorResult.next(request);
    }
    return fnp.InterceptorResult.reject(
      fnp.HttpStatusException(
        statusCode: _conflict,
        message: 'queued request is not owned by the current session',
        request: request,
      ),
    );
  }

  static const int _conflict = 409;

  /// Reads the idempotency key from [headers], ignoring case.
  static String? idempotencyKeyOf(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == idempotencyHeader) return entry.value;
    }
    return null;
  }
}
