import '../../domain/entities/activity_item.dart';
import 'json_reader.dart';

/// API representation of an [ActivityItem].
class ActivityItemModel {
  /// Creates a model.
  const ActivityItemModel({
    required this.id,
    required this.actorName,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  /// Parses the API activity object. Unknown event types become
  /// [ActivityType.other] so new server events never break the feed.
  factory ActivityItemModel.fromJson(Json json) => ActivityItemModel(
    id: json.string('id'),
    actorName: json.string('actorName'),
    type: _parseType(json.string('type')),
    message: json.string('message'),
    createdAt: json.dateTime('createdAt'),
  );

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

  /// Builds a model from a domain entity.
  factory ActivityItemModel.fromEntity(ActivityItem item) => ActivityItemModel(
    id: item.id,
    actorName: item.actorName,
    type: item.type,
    message: item.message,
    createdAt: item.createdAt,
  );

  /// Serialises to the API shape, for local storage.
  Json toJson() => <String, Object?>{
    'id': id,
    'actorName': actorName,
    'type': type.name,
    'message': message,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Converts to the domain entity.
  ActivityItem toEntity() => ActivityItem(
    id: id,
    actorName: actorName,
    type: type,
    message: message,
    createdAt: createdAt,
  );

  static ActivityType _parseType(String raw) {
    for (final type in ActivityType.values) {
      if (type.name == raw) return type;
    }
    return ActivityType.other;
  }
}
