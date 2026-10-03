import '../../core/error/failure.dart';
import '../../core/logging/app_logger.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';
import '../requests/update_task_request.dart';
import '../validators/validators.dart';

/// Updates a task after validating the changed fields.
class UpdateTaskUseCase {
  /// Creates the use case.
  const UpdateTaskUseCase(this._repository, [this._logger]);

  final TaskRepository _repository;
  final AppLogger? _logger;

  /// Validates and applies [request] to the task with [id].
  ///
  /// Throws a `ValidationFailure` for malformed input. A request that changes
  /// nothing is rejected the same way.
  Future<Task> call(String id, UpdateTaskRequest request) async {
    _logger?.debug(LogTag.useCase, 'updateTask');
    final title = request.title;
    Validators.throwIfInvalid(<String, String?>{
      'id': Validators.requiredId(id),
      'title': title == null ? null : Validators.taskTitle(title),
      'description': Validators.taskDescription(request.description),
    });
    if (request.isEmpty) throw const ValidationFailure();
    return _repository.updateTask(
      id,
      UpdateTaskRequest(
        title: title?.trim(),
        description: request.description?.trim(),
        status: request.status,
        priority: request.priority,
        assigneeId: request.assigneeId,
        dueDate: request.dueDate,
        clearDueDate: request.clearDueDate,
      ),
    );
  }
}
