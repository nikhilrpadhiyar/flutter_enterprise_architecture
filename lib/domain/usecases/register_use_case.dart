import '../../core/logging/app_logger.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../requests/register_request.dart';
import '../validators/validators.dart';

/// Creates an account after validating the details.
class RegisterUseCase {
  /// Creates the use case.
  const RegisterUseCase(this._repository, [this._logger]);

  final AuthRepository _repository;
  final AppLogger? _logger;

  /// Registers a new user.
  ///
  /// Throws a `ValidationFailure` for malformed input.
  Future<User> call(RegisterRequest request) async {
    _logger?.debug(LogTag.useCase, 'register');
    Validators.throwIfInvalid(<String, String?>{
      'name': Validators.name(request.name),
      'email': Validators.email(request.email),
      'password': Validators.newPassword(request.password),
    });
    return _repository.register(
      RegisterRequest(
        name: request.name.trim(),
        email: request.email.trim(),
        password: request.password,
      ),
    );
  }
}
