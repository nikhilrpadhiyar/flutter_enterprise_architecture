import '../entities/loaded.dart';
import '../entities/user.dart';
import '../requests/update_profile_request.dart';

/// The signed-in user's own profile.
abstract interface class ProfileRepository {
  /// Loads the profile, falling back to saved data when offline.
  Future<Loaded<User>> getProfile();

  /// Saves profile changes and returns the updated user.
  Future<User> updateProfile(UpdateProfileRequest request);
}
