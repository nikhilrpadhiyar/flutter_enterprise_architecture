import '../../core/logging/app_logger.dart';
import '../../domain/entities/loaded.dart';
import '../../domain/entities/paged_result.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_query.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/remote/project_remote_data_source.dart';

/// [ProjectRepository] backed by the remote project endpoints.
class ProjectRepositoryImpl implements ProjectRepository {
  /// Creates the repository.
  ProjectRepositoryImpl(this._remote, this._logger);

  final ProjectRemoteDataSource _remote;
  final AppLogger _logger;

  @override
  Future<Loaded<PagedResult<Project>>> getProjects(ProjectQuery query) async {
    _logger.debug(
      LogTag.repository,
      'getProjects',
      context: <String, Object?>{'page': query.page, 'search': query.search},
    );
    final data = await _remote.getProjects(query);
    return Loaded(
      data.value.toEntity((model) => model.toEntity()),
      isStale: data.fromCache,
    );
  }

  @override
  Future<Loaded<Project>> getProject(String id) async {
    _logger.debug(
      LogTag.repository,
      'getProject',
      context: <String, Object?>{'id': id},
    );
    final data = await _remote.getProject(id);
    return Loaded(data.value.toEntity(), isStale: data.fromCache);
  }
}
