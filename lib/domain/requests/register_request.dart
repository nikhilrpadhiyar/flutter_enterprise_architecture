import 'package:equatable/equatable.dart';

/// Details needed to create an account.
final class RegisterRequest extends Equatable {
  /// Creates a registration request.
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });

  /// Display name.
  final String name;

  /// Email address.
  final String email;

  /// Chosen password.
  final String password;

  @override
  List<Object?> get props => <Object?>[name, email, password];
}
