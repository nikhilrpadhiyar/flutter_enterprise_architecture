import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/stale_data_banner.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_status.dart';
import '../controllers/task_detail_controller.dart';
import '../widgets/activity_tile.dart';
import '../widgets/sync_state_badge.dart';
import '../widgets/task_labels.dart';

/// Everything about one task: fields, attachments and activity.
class TaskDetailPage extends StatelessWidget {
  /// Creates the page.
  const TaskDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TaskDetailController>(
      id: TaskDetailController.detailId,
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.taskDetailTitle),
          actions: <Widget>[
            IconButton(
              tooltip: AppStrings.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: controller.canModify ? controller.openEdit : null,
            ),
            IconButton(
              tooltip: AppStrings.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: controller.canModify
                  ? () => _confirmDelete(context, controller)
                  : null,
            ),
          ],
        ),
        body: SafeArea(child: _content(controller)),
      ),
    );
  }

  Widget _content(TaskDetailController controller) {
    final task = controller.task;
    if (task == null) {
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
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            if (controller.isStale) ...<Widget>[
              const StaleDataBanner(),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (controller.hasRejectedChange) ...<Widget>[
              AppBanner(
                message: AppStrings.changeRejected,
                isError: true,
                action: TextButton(
                  onPressed: controller.discardChanges,
                  child: const Text(AppStrings.discardChanges),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (controller.actionError != null) ...<Widget>[
              AppBanner(message: controller.actionError!, isError: true),
              const SizedBox(height: AppSpacing.sm),
            ],
            _Header(task),
            const SizedBox(height: AppSpacing.md),
            _Fields(task, controller),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: AppStrings.attachments,
              emptyText: AppStrings.noAttachments,
              children: <Widget>[
                for (final attachment in task.attachments)
                  _AttachmentTile(attachment),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: AppStrings.activity,
              emptyText: AppStrings.noActivity,
              children: <Widget>[
                for (final item in task.activity) ActivityTile(item),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskDetailController controller,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: AppStrings.deleteTaskTitle,
      message: AppStrings.deleteTaskMessage,
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );
    if (confirmed) await controller.delete();
  }
}

class _Header extends StatelessWidget {
  const _Header(this.task);

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(task.title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        SyncStateBadge(task.syncState),
      ],
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields(this.task, this.controller);

  final Task task;
  final TaskDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final due = task.dueDate;
    final overdue = task.isOverdue(DateTime.now());
    return GetBuilder<TaskDetailController>(
      id: TaskDetailController.actionsId,
      builder: (controller) {
        final enabled = controller.canModify;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _Dropdown<TaskStatus>(
                  label: AppStrings.statusLabel,
                  value: controller.task?.status ?? task.status,
                  values: TaskStatus.values,
                  text: TaskLabels.status,
                  onChanged: enabled ? controller.changeStatus : null,
                ),
                _Dropdown<TaskPriority>(
                  label: AppStrings.priorityLabel,
                  value: controller.task?.priority ?? task.priority,
                  values: TaskPriority.values,
                  text: TaskLabels.priority,
                  onChanged: enabled ? controller.changePriority : null,
                ),
              ],
            ),
            if (controller.isBusy) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.md),
            _InfoRow(
              icon: Icons.person_outline,
              label: AppStrings.assigneeLabel,
              value: task.assignee?.name.isNotEmpty ?? false
                  ? task.assignee!.name
                  : AppStrings.unassigned,
            ),
            _InfoRow(
              icon: Icons.event_outlined,
              label: AppStrings.dueDateLabel,
              value: due == null
                  ? AppStrings.noDueDate
                  : (overdue
                        ? '${AppStrings.overdue} ${AppFormatters.date(due)}'
                        : AppFormatters.date(due)),
              valueColor: overdue ? semantic.danger : null,
            ),
            if (task.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.descriptionLabel,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(task.description, style: theme.textTheme.bodyLarge),
            ],
          ],
        );
      },
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) text;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.dropdownWidth,
      child: DropdownButtonFormField<T>(
        key: ValueKey<T>(value),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: <DropdownMenuItem<T>>[
          for (final option in values)
            DropdownMenuItem<T>(
              value: option,
              child: Text(text(option), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (selected) {
                if (selected != null) onChanged!(selected);
              },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Icon(icon, size: AppSizes.icon, color: theme.colorScheme.outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: '$label: ', style: theme.textTheme.titleSmall),
                  TextSpan(
                    text: value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (children.isEmpty)
          Text(emptyText, style: theme.textTheme.bodyMedium)
        else
          ...children,
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile(this.attachment);

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attach_file),
      title: Text(attachment.name),
      subtitle: Text(AppFormatters.fileSize(attachment.sizeBytes)),
    );
  }
}
