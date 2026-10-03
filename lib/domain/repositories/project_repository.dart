import '../entities/loaded.dart';
import '../entities/paged_result.dart';
import '../entities/project.dart';
import '../entities/project_query.dart';

/// Read access to projects.
abstract interface class ProjectRepository {
  /// Loads one page of projects, falling back to saved data when offline.
  Future<Loaded<PagedResult<Project>>> getProjects(ProjectQuery query);

  /// Loads one project, falling back to saved data when offline.
  Future<Loaded<Project>> getProject(String id);
}
