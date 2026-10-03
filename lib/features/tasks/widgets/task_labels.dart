import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_sort.dart';
import '../../../domain/entities/task_status.dart';

/// User-facing names, icons and colours for task enums.
abstract final class TaskLabels {
  /// Display name of [status].
  static String status(TaskStatus status) => switch (status) {
    TaskStatus.todo => AppStrings.statusTodo,
    TaskStatus.inProgress => AppStrings.statusInProgress,
    TaskStatus.done => AppStrings.statusDone,
  };

  /// Display name of [priority].
  static String priority(TaskPriority priority) => switch (priority) {
    TaskPriority.low => AppStrings.priorityLow,
    TaskPriority.medium => AppStrings.priorityMedium,
    TaskPriority.high => AppStrings.priorityHigh,
    TaskPriority.urgent => AppStrings.priorityUrgent,
  };

  /// Display name of [sort].
  static String sort(TaskSort sort) => switch (sort) {
    TaskSort.dueDateAscending => AppStrings.sortDueSoonest,
    TaskSort.dueDateDescending => AppStrings.sortDueLatest,
    TaskSort.priority => AppStrings.sortPriority,
    TaskSort.recentlyUpdated => AppStrings.sortRecent,
  };

  /// Icon of [status].
  static IconData statusIcon(TaskStatus status) => switch (status) {
    TaskStatus.todo => Icons.radio_button_unchecked,
    TaskStatus.inProgress => Icons.timelapse,
    TaskStatus.done => Icons.check_circle_outline,
  };

  /// Colour of [status] in the current theme.
  static Color statusColor(BuildContext context, TaskStatus status) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return switch (status) {
      TaskStatus.todo => theme.colorScheme.outline,
      TaskStatus.inProgress => semantic.info,
      TaskStatus.done => semantic.success,
    };
  }

  /// Colour of [priority] in the current theme.
  static Color priorityColor(BuildContext context, TaskPriority priority) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return switch (priority) {
      TaskPriority.low => theme.colorScheme.outline,
      TaskPriority.medium => semantic.info,
      TaskPriority.high => semantic.warning,
      TaskPriority.urgent => semantic.danger,
    };
  }
}
