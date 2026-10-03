import '../entities/loaded.dart';
import '../entities/paged_result.dart';
import '../entities/task.dart';
import '../entities/task_query.dart';
import '../requests/create_task_request.dart';
import '../requests/update_task_request.dart';

/// Reading and changing tasks.
///
/// Reads fall back to saved data when offline. Writes are applied locally
/// first; a returned task whose `syncState` is pending will be sent when the
/// network is available.
abstract interface class TaskRepository {
  /// Loads one page of tasks matching [query].
  Future<Loaded<PagedResult<Task>>> getTasks(TaskQuery query);

  /// Loads one task with its attachments and activity.
  Future<Loaded<Task>> getTask(String id);

  /// Creates a task.
  Future<Task> createTask(CreateTaskRequest request);

  /// Updates a task.
  Future<Task> updateTask(String id, UpdateTaskRequest request);

  /// Deletes a task.
  Future<void> deleteTask(String id);

  /// Throws away local changes that the server rejected and, when possible,
  /// restores the server's version of the task.
  Future<void> discardLocalChanges(String id);
}
