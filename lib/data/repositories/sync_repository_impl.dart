import '../../domain/repositories/sync_repository.dart';
import '../datasources/remote/sync_remote_data_source.dart';
import '../sync/offline_sync_handler.dart';

/// [SyncRepository] backed by the networking layer's offline queue.
class SyncRepositoryImpl implements SyncRepository {
  /// Creates the repository.
  SyncRepositoryImpl(this._remote, this._handler);

  final SyncRemoteDataSource _remote;
  final OfflineSyncHandler _handler;

  /// Emits the queue size, but only after the local database reflects the
  /// change that caused it, so listeners reload up-to-date data.
  @override
  Stream<int> get pendingChanges =>
      _remote.pendingChanges.asyncMap((count) async {
        await Future<void>.delayed(Duration.zero);
        await _handler.idle;
        return count;
      });

  @override
  Future<void> syncNow() => _remote.replayNow();
}
