import '../repositories/auth_repository.dart';

/// Signs the current user out and clears their local data.
class LogoutUseCase {
  /// Creates the use case.
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  /// Signs out.
  Future<void> call() => _repository.logout();
}
