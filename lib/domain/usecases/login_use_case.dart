import '../../core/logging/app_logger.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../validators/validators.dart';

/// Signs a user in after validating the credentials.
class LoginUseCase {
  /// Creates the use case.
  const LoginUseCase(this._repository, [this._logger]);

  final AuthRepository _repository;
  final AppLogger? _logger;

  /// Signs in with [email] and [password].
  ///
  /// Throws a `ValidationFailure` for malformed input.
  Future<User> call({required String email, required String password}) async {
    _logger?.debug(LogTag.useCase, 'login');
    Validators.throwIfInvalid(<String, String?>{
      'email': Validators.email(email),
      'password': Validators.requiredPassword(password),
    });
    return _repository.login(email: email.trim(), password: password);
  }
}
