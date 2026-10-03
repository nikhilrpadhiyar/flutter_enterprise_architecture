import '../repositories/auth_repository.dart';

/// Streams the moments when the user must sign in again.
class ObserveSessionExpiryUseCase {
  /// Creates the use case.
  const ObserveSessionExpiryUseCase(this._repository);

  final AuthRepository _repository;

  /// Emits whenever the session expires and cannot be refreshed.
  Stream<void> call() => _repository.onSessionExpired;
}
