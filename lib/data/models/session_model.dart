import 'json_reader.dart';
import 'user_model.dart';

/// Tokens issued by the auth endpoints: `{accessToken, refreshToken,
/// expiresIn}` with the lifetime in seconds.
class TokenModel {
  /// Creates a model.
  const TokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  /// Parses a token response.
  factory TokenModel.fromJson(Object? raw) => TokenModel._read(asJson(raw));

  factory TokenModel._read(Json json) => TokenModel(
    accessToken: json.string('accessToken'),
    refreshToken: json.string('refreshToken'),
    expiresIn: json.integer('expiresIn'),
  );

  /// Short lived access token.
  final String accessToken;

  /// Long lived refresh token.
  final String refreshToken;

  /// Access token lifetime in seconds.
  final int expiresIn;

  /// The moment the access token expires, given the current time [now].
  DateTime expiresAt(DateTime now) => now.add(Duration(seconds: expiresIn));
}

/// Response of login and registration: tokens plus the user.
class SessionModel {
  /// Creates a model.
  const SessionModel({required this.tokens, required this.user});

  /// Parses a session response.
  factory SessionModel.fromJson(Object? raw) {
    final json = asJson(raw);
    return SessionModel(
      tokens: TokenModel.fromJson(json),
      user: UserModel.fromJson(json['user']),
    );
  }

  /// Issued tokens.
  final TokenModel tokens;

  /// The signed-in user.
  final UserModel user;
}
