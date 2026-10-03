import '../../core/logging/app_logger.dart';
import '../repositories/task_repository.dart';
import '../validators/validators.dart';

/// Deletes a task.
class DeleteTaskUseCase {
  /// Creates the use case.
  const DeleteTaskUseCase(this._repository, [this._logger]);

  final TaskRepository _repository;
  final AppLogger? _logger;

  /// Deletes the task with [id].
  ///
  /// Throws a `ValidationFailure` when [id] is blank.
  Future<void> call(String id) async {
    _logger?.debug(LogTag.useCase, 'deleteTask');
    Validators.throwIfInvalid(<String, String?>{
      'id': Validators.requiredId(id),
    });
    await _repository.deleteTask(id);
  }
}
