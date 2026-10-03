import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../core/error/failure.dart';
import '../../../domain/requests/register_request.dart';
import '../../models/requests/request_bodies.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import 'api_endpoints.dart';
import 'remote_requester.dart';

/// Sign in, registration, sign out and session restoration.
///
/// Login and registration store the issued tokens in the token storage that
/// the networking client uses, which is how the client attaches and refreshes
/// them afterwards.
class AuthRemoteDataSource {
  /// Creates the data source.
  AuthRemoteDataSource(
    this._requester,
    this._tokenStorage, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RemoteRequester _requester;
  final fnp.TokenStorage _tokenStorage;
  final DateTime Function() _clock;

  /// Signs in and stores the tokens.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final session = await _requester.write<SessionModel>(
      fnp.HttpMethod.post,
      ApiEndpoints.login,
      body: RequestBodies.login(email: email, password: password),
      decoder: SessionModel.fromJson,
      authRequired: false,
    );
    await _storeTokens(session);
    return session.user;
  }

  /// Creates an account, signs in and stores the tokens.
  Future<UserModel> register(RegisterRequest request) async {
    final session = await _requester.write<SessionModel>(
      fnp.HttpMethod.post,
      ApiEndpoints.register,
      body: RequestBodies.register(request),
      decoder: SessionModel.fromJson,
      authRequired: false,
    );
    await _storeTokens(session);
    return session.user;
  }

  /// Tells the server to end the session, then clears local tokens.
  ///
  /// The server call is best effort: the user is signed out locally even when
  /// it fails.
  Future<void> logout() async {
    try {
      await _requester.write<Object?>(
        fnp.HttpMethod.post,
        ApiEndpoints.logout,
        decoder: (Object? json) => json,
      );
    } on Failure {
      // Local sign out must succeed regardless of the server.
    } finally {
      await _tokenStorage.clear();
    }
  }

  /// Loads the user for an existing session, or `null` when signed out.
  ///
  /// A session the server rejects clears the saved tokens and also returns
  /// `null`.
  Future<UserModel?> restoreSession() async {
    if (await _tokenStorage.read() == null) return null;
    try {
      final data = await _requester.read<UserModel>(
        ApiEndpoints.profile,
        decoder: UserModel.fromJson,
      );
      return data.value;
    } on AuthenticationFailure {
      await _tokenStorage.clear();
      return null;
    }
  }

  Future<void> _storeTokens(SessionModel session) {
    final tokens = session.tokens;
    return _tokenStorage.write(
      fnp.AuthTokenPair(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt(_clock()),
      ),
    );
  }
}
