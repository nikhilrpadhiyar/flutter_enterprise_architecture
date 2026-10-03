import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/task.dart';
import 'sync_state_badge.dart';
import 'task_chip.dart';
import 'task_labels.dart';

/// A task in a list.
class TaskCard extends StatelessWidget {
  /// Creates a card. [now] decides whether the task is overdue.
  const TaskCard({
    required this.task,
    required this.onTap,
    required this.now,
    super.key,
  });

  /// The task to show.
  final Task task;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// The current time.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final due = task.dueDate;
    final overdue = task.isOverdue(now);
    return AppCard(
      onTap: onTap,
      semanticLabel: task.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(task.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TaskChip(
                label: TaskLabels.status(task.status),
                color: TaskLabels.statusColor(context, task.status),
                icon: TaskLabels.statusIcon(task.status),
              ),
              TaskChip(
                label: TaskLabels.priority(task.priority),
                color: TaskLabels.priorityColor(context, task.priority),
              ),
              SyncStateBadge(task.syncState),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Icon(
                Icons.person_outline,
                size: AppSpacing.md,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  _assigneeName(task),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (due != null)
                Text(
                  overdue
                      ? '${AppStrings.overdue} ${AppFormatters.date(due)}'
                      : AppStrings.dueOn(AppFormatters.date(due)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: overdue ? semantic.danger : null,
                    fontWeight: overdue ? FontWeight.w600 : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _assigneeName(Task task) {
    final name = task.assignee?.name;
    return name == null || name.isEmpty ? AppStrings.unassigned : name;
  }
}
