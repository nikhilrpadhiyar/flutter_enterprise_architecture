/// A value read from the server, tagged with where it came from.
class RemoteData<T> {
  /// Creates remote data.
  const RemoteData(this.value, {required this.fromCache});

  /// The decoded value.
  final T value;

  /// Whether the networking layer served this from its response cache
  /// because the server could not be reached.
  final bool fromCache;
}

/// Result of a write that may be parked for later delivery.
sealed class MutationOutcome<T> {
  const MutationOutcome();
}

/// The server processed the write and returned [value].
final class Applied<T> extends MutationOutcome<T> {
  /// Creates an applied outcome.
  const Applied(this.value);

  /// The server's response.
  final T value;
}

/// The device is offline; the write was saved and will be sent automatically
/// when the connection returns.
final class Queued<T> extends MutationOutcome<T> {
  /// Creates a queued outcome.
  const Queued();
}
