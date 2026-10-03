import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_sort.dart';
import '../../../domain/entities/task_status.dart';
import 'task_labels.dart';

/// The filter and sort options chosen in [TaskFilterSheet].
class TaskFilterSelection {
  /// Creates a selection.
  const TaskFilterSelection({
    required this.statuses,
    required this.priorities,
    required this.sort,
  });

  /// Chosen statuses; empty means any.
  final Set<TaskStatus> statuses;

  /// Chosen priorities; empty means any.
  final Set<TaskPriority> priorities;

  /// Chosen ordering.
  final TaskSort sort;
}

/// Bottom sheet for choosing task filters and ordering.
class TaskFilterSheet extends StatefulWidget {
  /// Creates the sheet, starting from [initial].
  const TaskFilterSheet({required this.initial, super.key});

  /// The current selection.
  final TaskFilterSelection initial;

  /// Opens the sheet and returns the new selection, or null if dismissed.
  static Future<TaskFilterSelection?> show(
    BuildContext context,
    TaskFilterSelection initial,
  ) {
    return showModalBottomSheet<TaskFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: AppSizes.sheetMaxWidth),
      builder: (_) => TaskFilterSheet(initial: initial),
    );
  }

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late Set<TaskStatus> _statuses = Set.of(widget.initial.statuses);
  late Set<TaskPriority> _priorities = Set.of(widget.initial.priorities);
  late TaskSort _sort = widget.initial.sort;

  static const TaskSort _defaultSort = TaskSort.dueDateAscending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(AppStrings.filters, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.statusLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final status in TaskStatus.values)
                  FilterChip(
                    label: Text(TaskLabels.status(status)),
                    selected: _statuses.contains(status),
                    onSelected: (on) => setState(
                      () =>
                          on ? _statuses.add(status) : _statuses.remove(status),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.priorityLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final priority in TaskPriority.values)
                  FilterChip(
                    label: Text(TaskLabels.priority(priority)),
                    selected: _priorities.contains(priority),
                    onSelected: (on) => setState(
                      () => on
                          ? _priorities.add(priority)
                          : _priorities.remove(priority),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.sortBy, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final sort in TaskSort.values)
                  ChoiceChip(
                    label: Text(TaskLabels.sort(sort)),
                    selected: _sort == sort,
                    onSelected: (_) => setState(() => _sort = sort),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: AppStrings.reset,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => setState(() {
                      _statuses = <TaskStatus>{};
                      _priorities = <TaskPriority>{};
                      _sort = _defaultSort;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: AppStrings.apply,
                    onPressed: () => Navigator.of(context).pop(
                      TaskFilterSelection(
                        statuses: _statuses,
                        priorities: _priorities,
                        sort: _sort,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
