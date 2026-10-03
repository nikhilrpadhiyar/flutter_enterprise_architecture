import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/stale_data_banner.dart';
import '../../../domain/entities/project.dart';
import '../../tasks/widgets/task_card.dart';
import '../../tasks/widgets/task_chip.dart';
import '../controllers/project_detail_controller.dart';
import '../widgets/project_card.dart';

/// A project's details and a preview of its tasks.
class ProjectDetailPage extends StatelessWidget {
  /// Creates the page.
  const ProjectDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProjectDetailController>(
      id: ProjectDetailController.detailId,
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: Text(
            controller.project?.name ?? AppStrings.projectDetailTitle,
          ),
        ),
        body: SafeArea(child: _content(controller)),
      ),
    );
  }

  Widget _content(ProjectDetailController controller) {
    final project = controller.project;
    if (project == null) {
      return controller.status == ViewStatus.error
          ? AppErrorView(
              message: controller.errorMessage ?? AppStrings.failureUnknown,
              onRetry: controller.load,
            )
          : const AppLoader();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              if (controller.isStale) ...<Widget>[
                const StaleDataBanner(),
                const SizedBox(height: AppSpacing.sm),
              ],
              _Summary(project),
              const SizedBox(height: AppSpacing.lg),
              _TaskPreview(controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.project);

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            TaskChip(
              label: ProjectLabels.status(project.status),
              color: ProjectLabels.statusColor(context, project.status),
            ),
          ],
        ),
        if (project.description.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(project.description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.md),
        ProjectProgress(project: project),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.md,
          children: <Widget>[
            Text(
              AppStrings.taskCount(project.taskCount),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '${project.completedCount} ${AppStrings.statusDone.toLowerCase()}',
              style: theme.textTheme.bodyMedium,
            ),
            if (project.overdueCount > 0)
              Text(
                AppStrings.overdueCount(project.overdueCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: semantic.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TaskPreview extends StatelessWidget {
  const _TaskPreview(this.controller);

  final ProjectDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = controller.now;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            AppStrings.projectTasks,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (controller.tasksError != null)
          AppBanner(message: controller.tasksError!, isError: true)
        else if (controller.tasks.isEmpty)
          Text(AppStrings.projectHasNoTasks, style: theme.textTheme.bodyMedium)
        else ...<Widget>[
          for (final task in controller.tasks) ...<Widget>[
            TaskCard(
              key: ValueKey<String>(task.id),
              task: task,
              now: now,
              onTap: () => controller.openTask(task),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (controller.taskTotal > controller.tasks.length)
            AppButton(
              label: AppStrings.viewAllTasks,
              variant: AppButtonVariant.outlined,
              onPressed: controller.openAllTasks,
            ),
        ],
      ],
    );
  }
}
