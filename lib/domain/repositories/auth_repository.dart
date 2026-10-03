import '../entities/user.dart';
import '../requests/register_request.dart';

/// Account and session operations.
///
/// Token storage and refresh are handled by the networking layer, so this
/// interface never exposes tokens.
abstract interface class AuthRepository {
  /// Signs in and returns the signed-in user.
  Future<User> login({required String email, required String password});

  /// Creates an account, signs in and returns the new user.
  Future<User> register(RegisterRequest request);

  /// Signs out and clears all locally saved user data.
  Future<void> logout();

  /// Returns the user of a previously saved session, or `null` when signed
  /// out.
  Future<User?> restoreSession();

  /// Emits when the session can no longer be refreshed and the user must
  /// sign in again.
  Stream<void> get onSessionExpired;
}
