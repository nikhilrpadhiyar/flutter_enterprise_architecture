import 'package:equatable/equatable.dart';

/// A person a task is assigned to.
final class Assignee extends Equatable {
  /// Creates an assignee.
  const Assignee({required this.id, required this.name});

  /// User identifier.
  final String id;

  /// Display name.
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];
}
