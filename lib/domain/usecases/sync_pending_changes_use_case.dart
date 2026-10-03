import '../repositories/sync_repository.dart';

/// Sends locally saved changes to the server now.
class SyncPendingChangesUseCase {
  /// Creates the use case.
  const SyncPendingChangesUseCase(this._repository);

  final SyncRepository _repository;

  /// Attempts to send all waiting changes.
  Future<void> call() => _repository.syncNow();
}
