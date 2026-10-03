import '../../core/logging/app_logger.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';
import '../requests/create_task_request.dart';
import '../validators/validators.dart';

/// Creates a task after validating the details.
class CreateTaskUseCase {
  /// Creates the use case.
  const CreateTaskUseCase(this._repository, [this._logger]);

  final TaskRepository _repository;
  final AppLogger? _logger;

  /// Validates and creates the task.
  ///
  /// Throws a `ValidationFailure` for malformed input.
  Future<Task> call(CreateTaskRequest request) async {
    _logger?.debug(LogTag.useCase, 'createTask');
    Validators.throwIfInvalid(<String, String?>{
      'title': Validators.taskTitle(request.title),
      'description': Validators.taskDescription(request.description),
      'projectId': Validators.requiredId(request.projectId),
    });
    return _repository.createTask(
      CreateTaskRequest(
        title: request.title.trim(),
        description: request.description.trim(),
        projectId: request.projectId,
        priority: request.priority,
        assigneeId: request.assigneeId,
        dueDate: request.dueDate,
      ),
    );
  }
}
