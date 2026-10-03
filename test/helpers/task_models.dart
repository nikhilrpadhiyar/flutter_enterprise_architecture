import 'package:flutter_enterprise_architecture/data/models/task_model.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';

/// A task model with sensible defaults for storage tests.
TaskModel taskModel({
  String id = 't1',
  String title = 'Write spec',
  String description = 'Draft the spec',
  TaskStatus status = TaskStatus.todo,
  TaskPriority priority = TaskPriority.medium,
  String projectId = 'p1',
  DateTime? dueDate,
  DateTime? updatedAt,
}) {
  final base = DateTime.utc(2026, 10, 1);
  return TaskModel(
    id: id,
    title: title,
    description: description,
    status: status,
    priority: priority,
    projectId: projectId,
    dueDate: dueDate,
    createdAt: base,
    updatedAt: updatedAt ?? base,
  );
}
