import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// A person who can sign in to the workspace.
final class User extends Equatable {
  /// Creates a user.
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  /// Unique identifier.
  final String id;

  /// Display name.
  final String name;

  /// Email address, used to sign in.
  final String email;

  /// Optional phone number.
  final String? phone;

  /// Workspace role.
  final UserRole role;

  @override
  List<Object?> get props => <Object?>[id, name, email, phone, role];
}
