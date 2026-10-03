import 'package:equatable/equatable.dart';

import 'activity_item.dart';
import 'assignee.dart';
import 'attachment.dart';
import 'sync_state.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// A unit of work within a project.
final class Task extends Equatable {
  /// Creates a task.
  const Task({
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
    this.attachments = const <Attachment>[],
    this.activity = const <ActivityItem>[],
    this.syncState = SyncState.synced,
  });

  /// Unique identifier.
  final String id;

  /// Short summary.
  final String title;

  /// Longer explanation, possibly empty.
  final String description;

  /// Progress.
  final TaskStatus status;

  /// Importance.
  final TaskPriority priority;

  /// Owning project.
  final String projectId;

  /// Person responsible, if any.
  final Assignee? assignee;

  /// Deadline, if any.
  final DateTime? dueDate;

  /// Attached files.
  final List<Attachment> attachments;

  /// Change history.
  final List<ActivityItem> activity;

  /// Creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether this local copy is confirmed by the server.
  final SyncState syncState;

  /// Whether the task is past its deadline and not finished at [now].
  bool isOverdue(DateTime now) {
    final due = dueDate;
    return due != null && status != TaskStatus.done && due.isBefore(now);
  }

  /// Returns a copy with the given fields replaced. Set [clearDueDate] to
  /// remove the deadline.
  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? projectId,
    Assignee? assignee,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<Attachment>? attachments,
    List<ActivityItem>? activity,
    DateTime? updatedAt,
    SyncState? syncState,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      assignee: assignee ?? this.assignee,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      attachments: attachments ?? this.attachments,
      activity: activity ?? this.activity,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    description,
    status,
    priority,
    projectId,
    assignee,
    dueDate,
    attachments,
    activity,
    createdAt,
    updatedAt,
    syncState,
  ];
}
