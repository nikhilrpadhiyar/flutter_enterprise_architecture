import 'package:equatable/equatable.dart';

/// Kind of event recorded in an activity feed.
enum ActivityType {
  /// An item was created.
  created,

  /// An item's fields changed.
  updated,

  /// A task changed status.
  statusChanged,

  /// Someone commented.
  commented,

  /// A task was assigned.
  assigned,

  /// Any event the app does not recognise.
  other,
}

/// One entry in a task or workspace activity feed.
final class ActivityItem extends Equatable {
  /// Creates an activity item.
  const ActivityItem({
    required this.id,
    required this.actorName,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  /// Unique identifier.
  final String id;

  /// Name of the person who acted.
  final String actorName;

  /// Kind of event.
  final ActivityType type;

  /// Human readable description.
  final String message;

  /// When the event happened.
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[id, actorName, type, message, createdAt];
}
