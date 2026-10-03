/// Orderings available for task lists.
enum TaskSort {
  /// Earliest deadline first.
  dueDateAscending,

  /// Latest deadline first.
  dueDateDescending,

  /// Highest priority first.
  priority,

  /// Most recently changed first.
  recentlyUpdated,
}
