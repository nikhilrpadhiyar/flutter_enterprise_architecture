import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Restores the user of a previously saved session at app start.
class RestoreSessionUseCase {
  /// Creates the use case.
  const RestoreSessionUseCase(this._repository);

  final AuthRepository _repository;

  /// Returns the signed-in user, or `null` when signed out.
  Future<User?> call() => _repository.restoreSession();
}
