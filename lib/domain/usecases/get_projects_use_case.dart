import '../entities/loaded.dart';
import '../entities/paged_result.dart';
import '../entities/project.dart';
import '../entities/project_query.dart';
import '../repositories/project_repository.dart';

/// Loads a page of projects.
class GetProjectsUseCase {
  /// Creates the use case.
  const GetProjectsUseCase(this._repository);

  final ProjectRepository _repository;

  /// Returns the projects matching [query].
  Future<Loaded<PagedResult<Project>>> call([
    ProjectQuery query = const ProjectQuery(),
  ]) => _repository.getProjects(query);
}
