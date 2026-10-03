import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_destinations.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/stale_data_banner.dart';
import '../controllers/project_list_controller.dart';
import '../widgets/project_card.dart';

/// The list of projects.
class ProjectListPage extends StatelessWidget {
  /// Creates the page.
  const ProjectListPage({super.key});

  static const double _loadMoreThreshold = 300;

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      destinations: AppDestinations.all,
      currentIndex: AppDestinations.indexOf(RouteNames.projects),
      onDestinationSelected: AppDestinations.open,
      title: AppStrings.projectsTitle,
      actions: <Widget>[
        IconButton(
          tooltip: AppStrings.tryAgain,
          icon: const Icon(Icons.refresh),
          onPressed: () => Get.find<ProjectListController>().reload(),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            GetBuilder<ProjectListController>(
              id: ProjectListController.bannerId,
              builder: (controller) => Column(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  AppTextField(
                    label: AppStrings.searchProjects,
                    prefixIcon: Icons.search,
                    controller: controller.searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: controller.onSearchChanged,
                  ),
                  if (controller.isStale) const StaleDataBanner(),
                  if (controller.refreshError != null)
                    AppBanner(message: controller.refreshError!, isError: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: GetBuilder<ProjectListController>(
                id: ProjectListController.listId,
                builder: (controller) => _Body(controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.controller);

  final ProjectListController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const AppLoader();
      case ViewStatus.error:
        return AppErrorView(
          message: controller.errorMessage ?? AppStrings.failureUnknown,
          onRetry: controller.load,
        );
      case ViewStatus.empty:
        return controller.hasSearch
            ? AppEmptyView(
                icon: Icons.search_off,
                title: AppStrings.noMatchingProjectsTitle,
                message: AppStrings.noMatchingTasksMessage,
                actionLabel: AppStrings.clearFilters,
                onAction: controller.clearSearch,
              )
            : const AppEmptyView(
                icon: Icons.folder_open,
                title: AppStrings.noProjectsTitle,
                message: AppStrings.noProjectsMessage,
              );
      case ViewStatus.success:
      case ViewStatus.refreshing:
      case ViewStatus.submitting:
        return _ProjectList(controller);
    }
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList(this.controller);

  final ProjectListController controller;

  @override
  Widget build(BuildContext context) {
    final projects = controller.projects;
    return Column(
      children: <Widget>[
        if (controller.status == ViewStatus.refreshing)
          const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.reload,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter <
                    ProjectListPage._loadMoreThreshold) {
                  controller.loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: projects.length + (controller.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  if (index == projects.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final project = projects[index];
                  return ProjectCard(
                    key: ValueKey<String>(project.id),
                    project: project,
                    onTap: () => controller.openProject(project),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
