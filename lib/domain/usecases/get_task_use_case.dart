import '../entities/loaded.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Loads one task with its attachments and activity.
class GetTaskUseCase {
  /// Creates the use case.
  const GetTaskUseCase(this._repository);

  final TaskRepository _repository;

  /// Returns the task with [id].
  Future<Loaded<Task>> call(String id) => _repository.getTask(id);
}
