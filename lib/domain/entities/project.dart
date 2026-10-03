import 'package:equatable/equatable.dart';

import 'project_status.dart';

/// A collection of related tasks.
final class Project extends Equatable {
  /// Creates a project.
  const Project({
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

  /// Unique identifier.
  final String id;

  /// Project name.
  final String name;

  /// What the project is about.
  final String description;

  /// Lifecycle state.
  final ProjectStatus status;

  /// User who owns the project.
  final String ownerId;

  /// Total number of tasks.
  final int taskCount;

  /// Number of overdue tasks.
  final int overdueCount;

  /// Number of finished tasks.
  final int completedCount;

  /// Creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Share of tasks that are finished, from 0 to 1.
  double get progress => taskCount == 0 ? 0 : completedCount / taskCount;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    description,
    status,
    ownerId,
    taskCount,
    overdueCount,
    completedCount,
    createdAt,
    updatedAt,
  ];
}
