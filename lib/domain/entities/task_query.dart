import 'package:equatable/equatable.dart';

import '../../core/constants/app_limits.dart';
import 'task_priority.dart';
import 'task_sort.dart';
import 'task_status.dart';

/// Search, filter, sort and paging options for listing tasks.
final class TaskQuery extends Equatable {
  /// Creates a query. All filters are optional.
  const TaskQuery({
    this.page = 1,
    this.pageSize = AppLimits.defaultPageSize,
    this.search = '',
    this.statuses = const <TaskStatus>{},
    this.priorities = const <TaskPriority>{},
    this.projectId,
    this.sort = TaskSort.dueDateAscending,
  });

  /// One-based page number.
  final int page;

  /// Items per page.
  final int pageSize;

  /// Free text matched against titles and descriptions.
  final String search;

  /// Only tasks with one of these statuses; empty means any.
  final Set<TaskStatus> statuses;

  /// Only tasks with one of these priorities; empty means any.
  final Set<TaskPriority> priorities;

  /// Restrict to one project.
  final String? projectId;

  /// Result ordering.
  final TaskSort sort;

  /// Whether any filter narrows the results.
  bool get hasFilters =>
      search.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      priorities.isNotEmpty ||
      projectId != null;

  /// Returns a copy with the given fields replaced.
  TaskQuery copyWith({
    int? page,
    int? pageSize,
    String? search,
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
    String? projectId,
    TaskSort? sort,
  }) {
    return TaskQuery(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      projectId: projectId ?? this.projectId,
      sort: sort ?? this.sort,
    );
  }

  /// The query for the following page.
  TaskQuery nextPage() => copyWith(page: page + 1);

  /// The same filters restarted from the first page.
  TaskQuery firstPage() => copyWith(page: 1);

  @override
  List<Object?> get props => <Object?>[
    page,
    pageSize,
    search,
    statuses,
    priorities,
    projectId,
    sort,
  ];
}
