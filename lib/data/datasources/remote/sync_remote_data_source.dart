import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

/// Exposes the networking layer's offline queue.
///
/// The queue itself, its persistence and its automatic replay on reconnect
/// are implemented by `flutter_network_plus`. This class only surfaces its
/// pending count and a manual replay trigger.
class SyncRemoteDataSource {
  /// Creates the data source over [client].
  SyncRemoteDataSource(this._client);

  final fnp.NetworkClient _client;

  /// Emits the number of queued requests: first the current count, then every
  /// change.
  Stream<int> get pendingChanges async* {
    final queue = _client.offlineQueue;
    if (queue == null) return;
    await queue.initialize();
    yield queue.pending;
    yield* queue.pendingChanges;
  }

  /// Replays queued requests now.
  Future<void> replayNow() async => _client.offlineQueue?.replayNow();
}
