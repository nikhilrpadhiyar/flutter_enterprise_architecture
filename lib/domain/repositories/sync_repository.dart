/// Visibility into, and control of, changes waiting to be sent.
abstract interface class SyncRepository {
  /// Emits the number of local changes still waiting to be sent.
  Stream<int> get pendingChanges;

  /// Tries to send waiting changes now.
  Future<void> syncNow();
}
