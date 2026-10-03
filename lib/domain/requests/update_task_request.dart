import 'package:equatable/equatable.dart';

import '../entities/task_priority.dart';
import '../entities/task_status.dart';

/// Task fields to change. Null fields are left as they are.
final class UpdateTaskRequest extends Equatable {
  /// Creates a request.
  const UpdateTaskRequest({
    this.title,
    this.description,
    this.status,
    this.priority,
    this.assigneeId,
    this.dueDate,
    this.clearDueDate = false,
  });

  /// New summary.
  final String? title;

  /// New explanation.
  final String? description;

  /// New progress.
  final TaskStatus? status;

  /// New importance.
  final TaskPriority? priority;

  /// New person responsible.
  final String? assigneeId;

  /// New deadline.
  final DateTime? dueDate;

  /// Remove the deadline. Takes precedence over [dueDate].
  final bool clearDueDate;

  /// Whether the request changes nothing.
  bool get isEmpty =>
      title == null &&
      description == null &&
      status == null &&
      priority == null &&
      assigneeId == null &&
      dueDate == null &&
      !clearDueDate;

  @override
  List<Object?> get props => <Object?>[
    title,
    description,
    status,
    priority,
    assigneeId,
    dueDate,
    clearDueDate,
  ];
}
