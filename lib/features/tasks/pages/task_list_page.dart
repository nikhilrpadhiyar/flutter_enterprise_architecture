import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_destinations.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/stale_data_banner.dart';
import '../../../domain/entities/task_sort.dart';
import '../controllers/task_list_controller.dart';
import '../widgets/task_card.dart';
import '../widgets/task_filter_sheet.dart';

/// The list of tasks with search, filters and infinite scrolling.
class TaskListPage extends StatelessWidget {
  /// Creates the page.
  const TaskListPage({super.key});

  /// Distance from the end of the list at which the next page is requested.
  static const double _loadMoreThreshold = 300;

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      destinations: AppDestinations.all,
      currentIndex: AppDestinations.indexOf(RouteNames.tasks),
      onDestinationSelected: AppDestinations.open,
      title: AppStrings.tasksTitle,
      actions: <Widget>[
        IconButton(
          tooltip: AppStrings.tryAgain,
          icon: const Icon(Icons.refresh),
          onPressed: () => Get.find<TaskListController>().reload(),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.find<TaskListController>().openCreate(),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.newTask),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            const _SearchBar(),
            const SizedBox(height: AppSpacing.sm),
            const _Banners(),
            Expanded(
              child: GetBuilder<TaskListController>(
                id: TaskListController.listId,
                builder: (controller) => _Body(controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TaskListController>(
      id: TaskListController.filtersId,
      builder: (controller) {
        final query = controller.query;
        final filterCount =
            query.statuses.length +
            query.priorities.length +
            (query.sort == TaskSort.dueDateAscending ? 0 : 1);
        return Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                label: AppStrings.searchTasks,
                prefixIcon: Icons.search,
                controller: controller.searchController,
                textInputAction: TextInputAction.search,
                onChanged: controller.onSearchChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: IconButton.filledTonal(
                tooltip: AppStrings.filters,
                icon: const Icon(Icons.tune),
                onPressed: () async {
                  final selection = await TaskFilterSheet.show(
                    context,
                    TaskFilterSelection(
                      statuses: query.statuses,
                      priorities: query.priorities,
                      sort: query.sort,
                    ),
                  );
                  if (selection != null) {
                    await controller.applyFilters(selection);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banners extends StatelessWidget {
  const _Banners();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TaskListController>(
      id: TaskListController.bannerId,
      builder: (controller) {
        final banners = <Widget>[
          if (controller.isStale) const StaleDataBanner(),
          if (controller.pendingChanges > 0)
            AppBanner(
              message: AppStrings.pendingChanges(controller.pendingChanges),
              icon: Icons.cloud_upload_outlined,
              action: TextButton(
                onPressed: controller.syncNow,
                child: const Text(AppStrings.syncNow),
              ),
            ),
          if (controller.refreshError != null)
            AppBanner(message: controller.refreshError!, isError: true),
        ];
        if (banners.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(spacing: AppSpacing.xs, children: banners),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.controller);

  final TaskListController controller;

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
        return controller.hasFilters
            ? AppEmptyView(
                icon: Icons.search_off,
                title: AppStrings.noMatchingTasksTitle,
                message: AppStrings.noMatchingTasksMessage,
                actionLabel: AppStrings.clearFilters,
                onAction: controller.clearFilters,
              )
            : AppEmptyView(
                icon: Icons.task_alt,
                title: AppStrings.noTasksTitle,
                message: AppStrings.noTasksMessage,
                actionLabel: AppStrings.newTask,
                onAction: controller.openCreate,
              );
      case ViewStatus.success:
      case ViewStatus.refreshing:
      case ViewStatus.submitting:
        return _TaskList(controller);
    }
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList(this.controller);

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.tasks;
    final now = controller.now;
    final hasFooter =
        controller.isLoadingMore || controller.loadMoreError != null;
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
                    TaskListPage._loadMoreThreshold) {
                  controller.loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.xxl + AppSpacing.xl,
                ),
                itemCount: tasks.length + (hasFooter ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  if (index == tasks.length) return _Footer(controller);
                  final task = tasks[index];
                  return TaskCard(
                    key: ValueKey<String>(task.id),
                    task: task,
                    now: now,
                    onTap: () => controller.openTask(task),
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

class _Footer extends StatelessWidget {
  const _Footer(this.controller);

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            Text(controller.loadMoreError!),
            AppButton(
              label: AppStrings.tryAgain,
              variant: AppButtonVariant.text,
              onPressed: controller.loadMore,
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
