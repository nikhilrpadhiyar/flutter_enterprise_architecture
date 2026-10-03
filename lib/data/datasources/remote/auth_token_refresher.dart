import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../models/requests/request_bodies.dart';
import '../../models/session_model.dart';
import 'api_endpoints.dart';

/// Exchanges an expired token pair for a new one.
///
/// Passed to the networking client's `AuthConfig`. The client calls this once
/// per refresh, queues concurrent requests behind it and retries them, so the
/// app never handles expiry itself. Throwing signals a terminal failure and
/// makes the client sign the user out.
class AuthTokenRefresher {
  /// Creates a refresher. [clock] is injectable for tests.
  AuthTokenRefresher({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Requests fresh tokens using [current]'s refresh token via [transport].
  Future<fnp.AuthTokenPair> call(
    fnp.AuthTokenPair current,
    fnp.RefreshTransport transport,
  ) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null) {
      throw StateError('No refresh token is available.');
    }
    final result = await transport.post<TokenModel>(
      ApiEndpoints.refresh,
      body: RequestBodies.refresh(refreshToken),
      decoder: TokenModel.fromJson,
    );
    final tokens = result.getOrThrow();
    return fnp.AuthTokenPair(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt(_clock()),
    );
  }
}
