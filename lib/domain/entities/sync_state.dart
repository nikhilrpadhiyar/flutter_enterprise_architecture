/// Whether a locally held record has been confirmed by the server.
enum SyncState {
  /// Matches the server.
  synced,

  /// Changed locally and waiting to be sent.
  pending,

  /// The server rejected the change.
  failed,
}
