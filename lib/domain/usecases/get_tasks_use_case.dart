import '../../core/constants/app_limits.dart';
import '../../core/logging/app_logger.dart';
import '../entities/loaded.dart';
import '../entities/paged_result.dart';
import '../entities/task.dart';
import '../entities/task_query.dart';
import '../repositories/task_repository.dart';

/// Loads a page of tasks.
class GetTasksUseCase {
  /// Creates the use case.
  const GetTasksUseCase(this._repository, [this._logger]);

  final TaskRepository _repository;
  final AppLogger? _logger;

  /// Returns the tasks matching [query].
  ///
  /// The page number and size are clamped to valid values and the search text
  /// is trimmed before the repository sees it.
  Future<Loaded<PagedResult<Task>>> call([
    TaskQuery query = const TaskQuery(),
  ]) {
    _logger?.debug(LogTag.useCase, 'getTasks');
    return _repository.getTasks(
      query.copyWith(
        page: query.page < 1 ? 1 : query.page,
        pageSize: query.pageSize.clamp(1, AppLimits.maxPageSize),
        search: query.search.trim(),
      ),
    );
  }
}
