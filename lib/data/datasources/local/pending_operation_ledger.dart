/// Records which queued network requests were created by the signed-in user
/// on this device.
///
/// The networking layer's offline queue cannot be emptied from outside, so
/// requests from a previous account could otherwise be replayed under a new
/// one. Before a queued request is replayed, the app asks the ledger whether
/// it still owns it.
abstract interface class PendingOperationLedger {
  /// Whether a change with the idempotency [key] is recorded.
  Future<bool> contains(String key);
}
