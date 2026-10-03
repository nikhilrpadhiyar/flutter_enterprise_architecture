import 'package:equatable/equatable.dart';

import '../../core/constants/app_limits.dart';

/// Search and paging options for listing projects.
final class ProjectQuery extends Equatable {
  /// Creates a query.
  const ProjectQuery({
    this.page = 1,
    this.pageSize = AppLimits.defaultPageSize,
    this.search = '',
  });

  /// One-based page number.
  final int page;

  /// Items per page.
  final int pageSize;

  /// Free text matched against project names.
  final String search;

  /// Returns a copy with the given fields replaced.
  ProjectQuery copyWith({int? page, int? pageSize, String? search}) {
    return ProjectQuery(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
    );
  }

  @override
  List<Object?> get props => <Object?>[page, pageSize, search];
}
