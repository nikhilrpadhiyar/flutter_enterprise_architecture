import '../../domain/entities/dashboard_summary.dart';
import 'activity_item_model.dart';
import 'json_reader.dart';
import 'task_model.dart';

/// API representation of a [DashboardSummary].
class DashboardSummaryModel {
  /// Creates a model.
  const DashboardSummaryModel({
    required this.projectCount,
    required this.openTaskCount,
    required this.completedTaskCount,
    required this.overdueTaskCount,
    required this.pendingTasks,
    required this.completedTasks,
    required this.recentActivity,
  });

  /// Parses the dashboard summary object.
  factory DashboardSummaryModel.fromJson(Object? raw) {
    final json = asJson(raw);
    return DashboardSummaryModel(
      projectCount: json.integer('projectCount'),
      openTaskCount: json.integer('openTaskCount'),
      completedTaskCount: json.integer('completedTaskCount'),
      overdueTaskCount: json.integer('overdueTaskCount'),
      pendingTasks: json
          .objects('pendingTasks')
          .map(TaskModel.fromJson)
          .toList(),
      completedTasks: json
          .objects('completedTasks')
          .map(TaskModel.fromJson)
          .toList(),
      recentActivity: json
          .objects('recentActivity')
          .map(ActivityItemModel.fromJson)
          .toList(),
    );
  }

  /// Number of projects.
  final int projectCount;

  /// Open tasks.
  final int openTaskCount;

  /// Finished tasks.
  final int completedTaskCount;

  /// Overdue open tasks.
  final int overdueTaskCount;

  /// Highlighted open tasks.
  final List<TaskModel> pendingTasks;

  /// Recently finished tasks.
  final List<TaskModel> completedTasks;

  /// Latest events.
  final List<ActivityItemModel> recentActivity;

  /// Converts to the domain entity.
  DashboardSummary toEntity() => DashboardSummary(
    projectCount: projectCount,
    openTaskCount: openTaskCount,
    completedTaskCount: completedTaskCount,
    overdueTaskCount: overdueTaskCount,
    pendingTasks: pendingTasks.map((t) => t.toEntity()).toList(),
    completedTasks: completedTasks.map((t) => t.toEntity()).toList(),
    recentActivity: recentActivity.map((a) => a.toEntity()).toList(),
  );
}
