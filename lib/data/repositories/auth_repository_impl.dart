import 'dart:async';

import '../../core/error/failure.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/requests/register_request.dart';
import '../datasources/local/session_local_data_source.dart';
import '../datasources/local/user_data_cleaner.dart';
import '../datasources/remote/auth_remote_data_source.dart';
import '../datasources/remote/sync_remote_data_source.dart';
import '../models/user_model.dart';
import '../session/session_expiry_notifier.dart';

/// [AuthRepository] backed by the remote auth endpoints and local storage of
/// the signed-in user.
class AuthRepositoryImpl implements AuthRepository {
  /// Creates the repository.
  AuthRepositoryImpl(
    this._remote,
    this._session,
    this._cleaner,
    this._sync,
    this._expiry,
    this._logger,
  );

  /// How long sign out waits for waiting changes to be delivered.
  static const Duration flushTimeout = Duration(seconds: 5);

  final AuthRemoteDataSource _remote;
  final SessionLocalDataSource _session;
  final UserDataCleaner _cleaner;
  final SyncRemoteDataSource _sync;
  final SessionExpiryNotifier _expiry;
  final AppLogger _logger;

  @override
  Future<User> login({required String email, required String password}) async {
    _logger.debug(LogTag.repository, 'login');
    return _remember(await _remote.login(email: email, password: password));
  }

  @override
  Future<User> register(RegisterRequest request) async {
    _logger.debug(LogTag.repository, 'register');
    return _remember(await _remote.register(request));
  }

  @override
  Future<void> logout() async {
    _logger.debug(LogTag.repository, 'logout');
    await _flushWaitingChanges();
    await _remote.logout();
    await _cleaner.clear();
  }

  @override
  Future<User?> restoreSession() async {
    _logger.debug(LogTag.repository, 'restoreSession');
    try {
      final user = await _remote.restoreSession();
      if (user == null) return null;
      await _saveUserLocally(user);
      return user.toEntity();
    } on Failure catch (failure) {
      final unreachable =
          failure is NetworkFailure ||
          failure is OfflineFailure ||
          failure is TimeoutFailure ||
          failure is ServerFailure;
      final saved = unreachable ? await _session.readUser() : null;
      if (saved == null) rethrow;
      return saved.toEntity();
    }
  }

  @override
  Stream<void> get onSessionExpired => _expiry.onExpired;

  /// Saves the signed-in [user], first discarding the data of a different
  /// user who used this device before.
  Future<User> _remember(UserModel user) async {
    try {
      final previous = await _session.readUser();
      if (previous != null && previous.id != user.id) await _cleaner.clear();
    } on CacheFailure catch (failure) {
      _logger.warning(
        LogTag.repository,
        'could not check the previous user',
        error: failure,
      );
    }
    await _saveUserLocally(user);
    return user.toEntity();
  }

  /// Keeps the user for offline start. Failing to do so must not fail a
  /// sign in that already succeeded.
  Future<void> _saveUserLocally(UserModel user) async {
    try {
      await _session.saveUser(user);
    } on CacheFailure catch (failure) {
      _logger.warning(
        LogTag.repository,
        'could not save the signed-in user',
        error: failure,
      );
    }
  }

  /// Gives changes made offline a chance to reach the server before the
  /// session ends. Failures are ignored: the user is signed out regardless.
  Future<void> _flushWaitingChanges() async {
    try {
      await _sync.replayNow().timeout(flushTimeout);
    } on Object catch (error) {
      _logger.warning(
        LogTag.repository,
        'could not send waiting changes before sign out',
        error: error,
      );
    }
  }
}
