import 'package:equatable/equatable.dart';

import 'activity_item.dart';
import 'task.dart';

/// Headline numbers and short lists shown on the dashboard.
final class DashboardSummary extends Equatable {
  /// Creates a summary.
  const DashboardSummary({
    required this.projectCount,
    required this.openTaskCount,
    required this.completedTaskCount,
    required this.overdueTaskCount,
    required this.pendingTasks,
    required this.completedTasks,
    required this.recentActivity,
  });

  /// Number of projects.
  final int projectCount;

  /// Tasks that are not finished.
  final int openTaskCount;

  /// Tasks that are finished.
  final int completedTaskCount;

  /// Open tasks past their deadline.
  final int overdueTaskCount;

  /// A few open tasks to highlight.
  final List<Task> pendingTasks;

  /// A few recently finished tasks.
  final List<Task> completedTasks;

  /// Latest workspace events.
  final List<ActivityItem> recentActivity;

  @override
  List<Object?> get props => <Object?>[
    projectCount,
    openTaskCount,
    completedTaskCount,
    overdueTaskCount,
    pendingTasks,
    completedTasks,
    recentActivity,
  ];
}
