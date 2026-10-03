import '../entities/assignee.dart';
import '../entities/loaded.dart';
import '../repositories/assignee_repository.dart';

/// Loads the people a task can be assigned to.
class GetAssigneesUseCase {
  /// Creates the use case.
  const GetAssigneesUseCase(this._repository);

  final AssigneeRepository _repository;

  /// Returns the available assignees.
  Future<Loaded<List<Assignee>>> call() => _repository.getAssignees();
}
