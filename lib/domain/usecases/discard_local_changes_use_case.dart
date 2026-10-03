import '../../core/logging/app_logger.dart';
import '../repositories/task_repository.dart';
import '../validators/validators.dart';

/// Drops a task's rejected local changes.
class DiscardLocalChangesUseCase {
  /// Creates the use case.
  const DiscardLocalChangesUseCase(this._repository, [this._logger]);

  final TaskRepository _repository;
  final AppLogger? _logger;

  /// Discards the unsent or rejected changes of the task with [id].
  ///
  /// Throws a `ValidationFailure` when [id] is blank.
  Future<void> call(String id) async {
    _logger?.debug(LogTag.useCase, 'discardLocalChanges');
    Validators.throwIfInvalid(<String, String?>{
      'id': Validators.requiredId(id),
    });
    await _repository.discardLocalChanges(id);
  }
}
