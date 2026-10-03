import '../../core/logging/app_logger.dart';
import '../entities/user.dart';
import '../repositories/profile_repository.dart';
import '../requests/update_profile_request.dart';
import '../validators/validators.dart';

/// Saves changes to the signed-in user's profile.
class UpdateProfileUseCase {
  /// Creates the use case.
  const UpdateProfileUseCase(this._repository, [this._logger]);

  final ProfileRepository _repository;
  final AppLogger? _logger;

  /// Validates and saves [request].
  ///
  /// Throws a `ValidationFailure` for malformed input.
  Future<User> call(UpdateProfileRequest request) async {
    _logger?.debug(LogTag.useCase, 'updateProfile');
    final name = request.name;
    Validators.throwIfInvalid(<String, String?>{
      'name': name == null ? null : Validators.name(name),
    });
    return _repository.updateProfile(
      UpdateProfileRequest(name: name?.trim(), phone: request.phone?.trim()),
    );
  }
}
