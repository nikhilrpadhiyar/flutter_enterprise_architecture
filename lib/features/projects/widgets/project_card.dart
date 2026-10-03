import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/project_status.dart';
import '../../tasks/widgets/task_chip.dart';

/// Display names and colours for project statuses.
abstract final class ProjectLabels {
  /// Display name of [status].
  static String status(ProjectStatus status) => switch (status) {
    ProjectStatus.active => AppStrings.projectActive,
    ProjectStatus.onHold => AppStrings.projectOnHold,
    ProjectStatus.completed => AppStrings.projectCompleted,
  };

  /// Colour of [status] in the current theme.
  static Color statusColor(BuildContext context, ProjectStatus status) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return switch (status) {
      ProjectStatus.active => semantic.info,
      ProjectStatus.onHold => semantic.warning,
      ProjectStatus.completed => semantic.success,
    };
  }
}

/// A project in a list.
class ProjectCard extends StatelessWidget {
  /// Creates a card.
  const ProjectCard({required this.project, required this.onTap, super.key});

  /// The project to show.
  final Project project;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return AppCard(
      onTap: onTap,
      semanticLabel: project.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(project.name, style: theme.textTheme.titleMedium),
              ),
              TaskChip(
                label: ProjectLabels.status(project.status),
                color: ProjectLabels.statusColor(context, project.status),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              project.description,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ProjectProgress(project: project),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Text(
                AppStrings.taskCount(project.taskCount),
                style: theme.textTheme.bodySmall,
              ),
              if (project.overdueCount > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.overdueCount(project.overdueCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A progress bar for the finished share of a project's tasks.
class ProjectProgress extends StatelessWidget {
  /// Creates a progress bar.
  const ProjectProgress({required this.project, super.key});

  /// The project to show.
  final Project project;

  @override
  Widget build(BuildContext context) {
    final percent = (project.progress * 100).round();
    return Semantics(
      label: AppStrings.percentComplete(percent),
      child: ExcludeSemantics(
        child: LinearProgressIndicator(value: project.progress),
      ),
    );
  }
}
