import '../../domain/entities/task.dart';
import '../../domain/entities/task_priority.dart';
import '../../domain/entities/task_status.dart';
import 'activity_item_model.dart';
import 'assignee_model.dart';
import 'attachment_model.dart';
import 'json_reader.dart';

/// API representation of a [Task].
class TaskModel {
  /// Creates a model.
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.projectId,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
    this.dueDate,
    this.attachments = const <AttachmentModel>[],
    this.activity = const <ActivityItemModel>[],
  });

  /// Parses the API task object.
  factory TaskModel.fromJson(Object? raw) {
    final json = asJson(raw);
    final assignee = json.objectOrNull('assignee');
    return TaskModel(
      id: json.string('id'),
      title: json.string('title'),
      description: json.stringOrNull('description') ?? '',
      status: parseEnum(TaskStatus.values, json.string('status')),
      priority: parseEnum(TaskPriority.values, json.string('priority')),
      projectId: json.string('projectId'),
      assignee: assignee == null ? null : AssigneeModel.fromJson(assignee),
      dueDate: json.dateTimeOrNull('dueDate'),
      attachments: json
          .objects('attachments')
          .map(AttachmentModel.fromJson)
          .toList(),
      activity: json
          .objects('activity')
          .map(ActivityItemModel.fromJson)
          .toList(),
      createdAt: json.dateTime('createdAt'),
      updatedAt: json.dateTime('updatedAt'),
    );
  }

  /// Unique identifier.
  final String id;

  /// Short summary.
  final String title;

  /// Longer explanation.
  final String description;

  /// Progress.
  final TaskStatus status;

  /// Importance.
  final TaskPriority priority;

  /// Owning project.
  final String projectId;

  /// Person responsible.
  final AssigneeModel? assignee;

  /// Deadline.
  final DateTime? dueDate;

  /// Attached files.
  final List<AttachmentModel> attachments;

  /// Change history.
  final List<ActivityItemModel> activity;

  /// Creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Builds a model from a domain entity, for tasks created or edited on
  /// this device.
  factory TaskModel.fromEntity(Task task) => TaskModel(
    id: task.id,
    title: task.title,
    description: task.description,
    status: task.status,
    priority: task.priority,
    projectId: task.projectId,
    assignee: task.assignee == null
        ? null
        : AssigneeModel.fromEntity(task.assignee!),
    dueDate: task.dueDate,
    attachments: task.attachments.map(AttachmentModel.fromEntity).toList(),
    activity: task.activity.map(ActivityItemModel.fromEntity).toList(),
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  );

  /// Serialises to the API shape, for local storage.
  Json toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'description': description,
    'status': status.name,
    'priority': priority.name,
    'projectId': projectId,
    'assignee': assignee?.toJson(),
    'dueDate': dueDate?.toUtc().toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'activity': activity.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  /// Converts to the domain entity.
  Task toEntity() => Task(
    id: id,
    title: title,
    description: description,
    status: status,
    priority: priority,
    projectId: projectId,
    assignee: assignee?.toEntity(),
    dueDate: dueDate,
    attachments: attachments.map((a) => a.toEntity()).toList(),
    activity: activity.map((a) => a.toEntity()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
