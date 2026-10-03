import '../entities/loaded.dart';
import '../entities/user.dart';
import '../repositories/profile_repository.dart';

/// Loads the signed-in user's profile.
class GetProfileUseCase {
  /// Creates the use case.
  const GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  /// Returns the profile.
  Future<Loaded<User>> call() => _repository.getProfile();
}
