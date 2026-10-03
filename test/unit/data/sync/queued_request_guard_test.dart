import 'package:flutter_enterprise_architecture/data/datasources/local/pending_operation_ledger.dart';
import 'package:flutter_enterprise_architecture/data/sync/queued_request_guard.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

class _Ledger implements PendingOperationLedger {
  _Ledger(this.keys);

  final Set<String> keys;

  @override
  Future<bool> contains(String key) async => keys.contains(key);
}

fnp.NetworkRequest _request({
  bool replayed = true,
  Map<String, String> headers = const <String, String>{},
}) => fnp.NetworkRequest(
  method: fnp.HttpMethod.post,
  path: 'tasks',
  headers: headers,
  extra: <String, Object?>{if (replayed) QueuedRequestGuard.replayedFlag: true},
);

void main() {
  final guard = QueuedRequestGuard(_Ledger({'k1'}));

  test('lets ordinary requests through without checking the ledger', () async {
    final result = await guard.onRequest(_request(replayed: false));
    expect(result, isA<fnp.InterceptorNext>());
  });

  test('lets a replay through when the ledger knows its key', () async {
    final result = await guard.onRequest(
      _request(headers: const {'Idempotency-Key': 'k1'}),
    );
    expect(result, isA<fnp.InterceptorNext>());
  });

  test('reads the header name case-insensitively', () async {
    final result = await guard.onRequest(
      _request(headers: const {'idempotency-key': 'k1'}),
    );
    expect(result, isA<fnp.InterceptorNext>());
  });

  test('rejects a replay whose key is not in the ledger', () async {
    final result = await guard.onRequest(
      _request(headers: const {'Idempotency-Key': 'someone-elses'}),
    );
    expect(result, isA<fnp.InterceptorReject>());
    final exception = (result as fnp.InterceptorReject).exception;
    expect(exception, isA<fnp.HttpStatusException>());
    // A client error makes the queue drop the entry instead of retrying.
    expect((exception as fnp.HttpStatusException).isClientError, isTrue);
  });

  test('rejects a replay that has no key at all', () async {
    final result = await guard.onRequest(_request());
    expect(result, isA<fnp.InterceptorReject>());
  });
}
