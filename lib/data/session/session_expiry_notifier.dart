import 'dart:async';

/// Broadcasts the moment the session can no longer be refreshed.
///
/// The networking client calls [notify] from its auth-failure hook, and the
/// auth repository exposes [onExpired] to the rest of the app.
class SessionExpiryNotifier {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Emits whenever [notify] is called.
  Stream<void> get onExpired => _controller.stream;

  /// Signals that the user must sign in again.
  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  /// Releases the stream.
  Future<void> dispose() => _controller.close();
}
