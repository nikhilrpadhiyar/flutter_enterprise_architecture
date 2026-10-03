import '../entities/loaded.dart';
import '../entities/project.dart';
import '../repositories/project_repository.dart';

/// Loads one project.
class GetProjectUseCase {
  /// Creates the use case.
  const GetProjectUseCase(this._repository);

  final ProjectRepository _repository;

  /// Returns the project with [id].
  Future<Loaded<Project>> call(String id) => _repository.getProject(id);
}
