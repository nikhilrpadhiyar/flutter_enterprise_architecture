import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../domain/entities/task_priority.dart';
import '../controllers/task_form_controller.dart';
import '../widgets/task_labels.dart';

/// Form for creating a task, or editing one when the route has an id.
class TaskFormPage extends StatelessWidget {
  /// Creates the page.
  const TaskFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TaskFormController>(
      id: TaskFormController.formId,
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: Text(
            controller.isEditing
                ? AppStrings.editTaskTitle
                : AppStrings.newTask,
          ),
        ),
        body: SafeArea(child: _content(context, controller)),
      ),
    );
  }

  Widget _content(BuildContext context, TaskFormController controller) {
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
        return const AppEmptyView(
          icon: Icons.folder_off_outlined,
          title: AppStrings.noProjectsTitle,
          message: AppStrings.noProjectsMessage,
        );
      case ViewStatus.success:
      case ViewStatus.refreshing:
      case ViewStatus.submitting:
        return _Form(controller);
    }
  }
}

class _Form extends StatelessWidget {
  const _Form(this.controller);

  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isSubmitting;
    final errors = controller.fieldErrors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (controller.formError != null) ...<Widget>[
                AppBanner(message: controller.formError!, isError: true),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: AppStrings.taskTitleLabel,
                controller: controller.titleController,
                errorText: errors['title'],
                enabled: !busy,
                textInputAction: TextInputAction.next,
                onChanged: controller.onTitleChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.descriptionLabel,
                controller: controller.descriptionController,
                errorText: errors['description'],
                enabled: !busy,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                onChanged: controller.onDescriptionChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('project-${controller.projectId}'),
                initialValue: controller.projectId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppStrings.projectLabel,
                  errorText: errors['projectId'],
                ),
                items: <DropdownMenuItem<String>>[
                  for (final project in controller.projects)
                    DropdownMenuItem<String>(
                      value: project.id,
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy || controller.isEditing
                    ? null
                    : controller.onProjectChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>('assignee-${controller.assigneeId}'),
                initialValue: controller.assigneeId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppStrings.assigneeLabel,
                  errorText: errors['assigneeId'],
                ),
                items: <DropdownMenuItem<String?>>[
                  if (controller.canUnassign)
                    const DropdownMenuItem<String?>(
                      child: Text(AppStrings.unassigned),
                    ),
                  for (final person in controller.assignees)
                    DropdownMenuItem<String?>(
                      value: person.id,
                      child: Text(person.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: busy ? null : controller.onAssigneeChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<TaskPriority>(
                key: ValueKey<TaskPriority>(controller.priority),
                initialValue: controller.priority,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppStrings.priorityLabel,
                  errorText: errors['priority'],
                ),
                items: <DropdownMenuItem<TaskPriority>>[
                  for (final priority in TaskPriority.values)
                    DropdownMenuItem<TaskPriority>(
                      value: priority,
                      child: Text(TaskLabels.priority(priority)),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) controller.onPriorityChanged(value);
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              _DueDateField(controller: controller, enabled: !busy),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: controller.isEditing
                    ? AppStrings.saveChanges
                    : AppStrings.newTask,
                expand: true,
                isLoading: busy,
                onPressed: controller.submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({required this.controller, required this.enabled});

  final TaskFormController controller;
  final bool enabled;

  static const int _yearsAhead = 10;

  @override
  Widget build(BuildContext context) {
    final due = controller.dueDate;
    final error = controller.fieldErrors['dueDate'];
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.event_outlined),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                due == null
                    ? AppStrings.setDueDate
                    : '${AppStrings.dueDateLabel}: ${AppFormatters.date(due)}',
              ),
            ),
            onPressed: enabled ? () => _pick(context) : null,
          ),
        ),
        if (due != null)
          IconButton(
            tooltip: AppStrings.clearDueDate,
            icon: const Icon(Icons.close),
            onPressed: enabled ? () => controller.onDueDateChanged(null) : null,
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + _yearsAhead),
    );
    if (picked != null) controller.onDueDateChanged(picked);
  }
}
