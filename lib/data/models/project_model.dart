import '../../domain/entities/project.dart';
import '../../domain/entities/project_status.dart';
import 'json_reader.dart';

/// API representation of a [Project].
class ProjectModel {
  /// Creates a model.
  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.ownerId,
    required this.taskCount,
    required this.overdueCount,
    required this.completedCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parses the API project object.
  factory ProjectModel.fromJson(Object? raw) {
    final json = asJson(raw);
    return ProjectModel(
      id: json.string('id'),
      name: json.string('name'),
      description: json.stringOrNull('description') ?? '',
      status: parseEnum(ProjectStatus.values, json.string('status')),
      ownerId: json.string('ownerId'),
      taskCount: json.integer('taskCount'),
      overdueCount: json.integer('overdueCount'),
      completedCount: json.integer('completedCount'),
      createdAt: json.dateTime('createdAt'),
      updatedAt: json.dateTime('updatedAt'),
    );
  }

  /// Unique identifier.
  final String id;

  /// Project name.
  final String name;

  /// Description.
  final String description;

  /// Lifecycle state.
  final ProjectStatus status;

  /// Owner user id.
  final String ownerId;

  /// Total tasks.
  final int taskCount;

  /// Overdue tasks.
  final int overdueCount;

  /// Finished tasks.
  final int completedCount;

  /// Creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Converts to the domain entity.
  Project toEntity() => Project(
    id: id,
    name: name,
    description: description,
    status: status,
    ownerId: ownerId,
    taskCount: taskCount,
    overdueCount: overdueCount,
    completedCount: completedCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
