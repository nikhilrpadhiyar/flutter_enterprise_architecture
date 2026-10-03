import 'package:equatable/equatable.dart';

/// Profile fields to change. Null fields are left as they are.
final class UpdateProfileRequest extends Equatable {
  /// Creates an update request.
  const UpdateProfileRequest({this.name, this.phone});

  /// New display name.
  final String? name;

  /// New phone number.
  final String? phone;

  @override
  List<Object?> get props => <Object?>[name, phone];
}
