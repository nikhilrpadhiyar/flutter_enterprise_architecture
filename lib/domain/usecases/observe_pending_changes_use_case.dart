import '../repositories/sync_repository.dart';

/// Streams the number of changes waiting to be sent.
class ObservePendingChangesUseCase {
  /// Creates the use case.
  const ObservePendingChangesUseCase(this._repository);

  final SyncRepository _repository;

  /// Emits the pending change count whenever it changes.
  Stream<int> call() => _repository.pendingChanges;
}
