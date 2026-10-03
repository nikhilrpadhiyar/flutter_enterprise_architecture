import 'package:equatable/equatable.dart';

import '../entities/task_priority.dart';

/// Data needed to create a task.
final class CreateTaskRequest extends Equatable {
  /// Creates a request.
  const CreateTaskRequest({
    required this.title,
    required this.projectId,
    required this.priority,
    this.description = '',
    this.assigneeId,
    this.dueDate,
  });

  /// Short summary.
  final String title;

  /// Longer explanation.
  final String description;

  /// Owning project.
  final String projectId;

  /// Person responsible.
  final String? assigneeId;

  /// Importance.
  final TaskPriority priority;

  /// Deadline.
  final DateTime? dueDate;

  @override
  List<Object?> get props => <Object?>[
    title,
    description,
    projectId,
    assigneeId,
    priority,
    dueDate,
  ];
}
