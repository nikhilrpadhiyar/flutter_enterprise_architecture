import '../../core/error/failure.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/loaded.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/requests/update_profile_request.dart';
import '../datasources/local/session_local_data_source.dart';
import '../datasources/remote/profile_remote_data_source.dart';
import '../models/user_model.dart';

/// [ProfileRepository] backed by the remote profile endpoints, with the last
/// known profile kept locally for offline use.
class ProfileRepositoryImpl implements ProfileRepository {
  /// Creates the repository.
  ProfileRepositoryImpl(this._remote, this._session, this._logger);

  final ProfileRemoteDataSource _remote;
  final SessionLocalDataSource _session;
  final AppLogger _logger;

  @override
  Future<Loaded<User>> getProfile() async {
    _logger.debug(LogTag.repository, 'getProfile');
    try {
      final data = await _remote.getProfile();
      await _saveLocally(data.value);
      return Loaded(data.value.toEntity(), isStale: data.fromCache);
    } on Failure catch (failure) {
      final unreachable =
          failure is NetworkFailure ||
          failure is OfflineFailure ||
          failure is TimeoutFailure ||
          failure is ServerFailure;
      final saved = unreachable ? await _session.readUser() : null;
      if (saved == null) rethrow;
      return Loaded(saved.toEntity(), isStale: true);
    }
  }

  @override
  Future<User> updateProfile(UpdateProfileRequest request) async {
    _logger.debug(LogTag.repository, 'updateProfile');
    final user = await _remote.updateProfile(request);
    await _saveLocally(user);
    return user.toEntity();
  }

  /// Keeps the profile for offline use. A failure is logged, not shown.
  Future<void> _saveLocally(UserModel user) async {
    try {
      await _session.saveUser(user);
    } on CacheFailure catch (failure) {
      _logger.warning(
        LogTag.repository,
        'could not save the profile',
        error: failure,
      );
    }
  }
}
