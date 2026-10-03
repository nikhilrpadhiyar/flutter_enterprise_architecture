import '../../domain/entities/user.dart';
import '../../domain/entities/user_role.dart';
import 'json_reader.dart';

/// API representation of a [User].
class UserModel {
  /// Creates a model.
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  /// Parses the API user object.
  factory UserModel.fromJson(Object? raw) {
    final json = asJson(raw);
    return UserModel(
      id: json.string('id'),
      name: json.string('name'),
      email: json.string('email'),
      phone: json.stringOrNull('phone'),
      role: parseEnum(UserRole.values, json.string('role')),
    );
  }

  /// Unique identifier.
  final String id;

  /// Display name.
  final String name;

  /// Email address.
  final String email;

  /// Phone number.
  final String? phone;

  /// Workspace role.
  final UserRole role;

  /// Serialises to the API shape, for local storage.
  Json toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.name,
  };

  /// Builds a model from a domain entity.
  factory UserModel.fromEntity(User user) => UserModel(
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role,
  );

  /// Converts to the domain entity.
  User toEntity() =>
      User(id: id, name: name, email: email, phone: phone, role: role);
}
