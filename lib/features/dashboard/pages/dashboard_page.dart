import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_destinations.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/screen_size.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/stale_data_banner.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../domain/entities/task.dart';
import '../../tasks/widgets/activity_tile.dart';
import '../../tasks/widgets/task_card.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/summary_tile.dart';

/// The home screen: figures, pending work, recent activity and shortcuts.
class DashboardPage extends StatelessWidget {
  /// Creates the page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      destinations: AppDestinations.all,
      currentIndex: AppDestinations.indexOf(RouteNames.dashboard),
      onDestinationSelected: AppDestinations.open,
      title: AppStrings.dashboardTitle,
      actions: <Widget>[
        IconButton(
          tooltip: AppStrings.tryAgain,
          icon: const Icon(Icons.refresh),
          onPressed: () => Get.find<DashboardController>().reload(),
        ),
      ],
      body: GetBuilder<DashboardController>(
        id: DashboardController.contentId,
        builder: (controller) => _Body(controller),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.controller);

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    if (summary == null) {
      return controller.status == ViewStatus.error
          ? AppErrorView(
              message: controller.errorMessage ?? AppStrings.failureUnknown,
              onRetry: controller.load,
            )
          : const AppLoader();
    }
    final isWide =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) !=
        ScreenSize.compact;
    final left = <Widget>[
      _SummaryGrid(summary),
      _TaskSection(
        title: AppStrings.pendingTasks,
        emptyText: AppStrings.noPendingTasks,
        tasks: summary.pendingTasks,
        controller: controller,
      ),
      _TaskSection(
        title: AppStrings.completedTasks,
        emptyText: AppStrings.noCompletedTasks,
        tasks: summary.completedTasks,
        controller: controller,
      ),
    ];
    final right = <Widget>[
      _QuickActions(controller),
      _ActivitySection(summary),
    ];
    return Column(
      children: <Widget>[
        if (controller.status == ViewStatus.refreshing)
          const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                if (controller.isStale) ...<Widget>[
                  const StaleDataBanner(),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (controller.refreshError != null) ...<Widget>[
                  AppBanner(message: controller.refreshError!, isError: true),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _Welcome(controller),
                const SizedBox(height: AppSpacing.md),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: _Column(left)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 2, child: _Column(right)),
                    ],
                  )
                else
                  _Column(<Widget>[
                    left.first,
                    right.first,
                    ...left.skip(1),
                    right.last,
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: children,
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome(this.controller);

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      id: DashboardController.welcomeId,
      builder: (controller) {
        final name = controller.firstName;
        return Semantics(
          header: true,
          child: Text(
            name.isEmpty
                ? AppStrings.dashboardTitle
                : AppStrings.greeting(name),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        );
      },
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid(this.summary);

  final DashboardSummary summary;

  static const double _fourColumnsFrom = 520;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final tiles = <Widget>[
      SummaryTile(
        label: AppStrings.projectsLabel,
        value: summary.projectCount,
        icon: Icons.folder_outlined,
      ),
      SummaryTile(
        label: AppStrings.openTasks,
        value: summary.openTaskCount,
        icon: Icons.pending_actions_outlined,
      ),
      SummaryTile(
        label: AppStrings.completedLabel,
        value: summary.completedTaskCount,
        icon: Icons.check_circle_outline,
        color: semantic.success,
      ),
      SummaryTile(
        label: AppStrings.overdueLabel,
        value: summary.overdueTaskCount,
        icon: Icons.event_busy_outlined,
        color: summary.overdueTaskCount > 0 ? semantic.danger : null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _fourColumnsFrom ? 4 : 2;
        final width =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions(this.controller);

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: AppStrings.quickActions,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          AppButton(
            label: AppStrings.newTask,
            icon: Icons.add,
            onPressed: controller.openCreateTask,
          ),
          AppButton(
            label: AppStrings.allTasks,
            variant: AppButtonVariant.outlined,
            onPressed: controller.openTasks,
          ),
          AppButton(
            label: AppStrings.projectsLabel,
            variant: AppButtonVariant.outlined,
            onPressed: controller.openProjects,
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.emptyText,
    required this.tasks,
    required this.controller,
  });

  final String title;
  final String emptyText;
  final List<Task> tasks;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    return _Section(
      title: title,
      child: tasks.isEmpty
          ? Text(emptyText, style: Theme.of(context).textTheme.bodyMedium)
          : Column(
              spacing: AppSpacing.xs,
              children: <Widget>[
                for (final task in tasks)
                  TaskCard(
                    key: ValueKey<String>('$title-${task.id}'),
                    task: task,
                    now: now,
                    onTap: () => controller.openTask(task),
                  ),
              ],
            ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection(this.summary);

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: AppStrings.recentActivity,
      child: summary.recentActivity.isEmpty
          ? Text(
              AppStrings.noRecentActivity,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: <Widget>[
                for (final item in summary.recentActivity) ActivityTile(item),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
