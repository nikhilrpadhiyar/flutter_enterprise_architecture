import '../../models/user_model.dart';

/// Local storage of the signed-in user, so the app can start offline.
abstract interface class SessionLocalDataSource {
  /// The saved user, or null.
  Future<UserModel?> readUser();

  /// Saves [user].
  Future<void> saveUser(UserModel user);

  /// Forgets the saved user.
  Future<void> clear();
}
