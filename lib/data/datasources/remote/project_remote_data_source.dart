import '../../../domain/entities/project_query.dart';
import '../../models/paged_model.dart';
import '../../models/project_model.dart';
import 'api_endpoints.dart';
import 'remote_outcome.dart';
import 'remote_requester.dart';

/// Project endpoints.
class ProjectRemoteDataSource {
  /// Creates the data source.
  ProjectRemoteDataSource(this._requester);

  final RemoteRequester _requester;

  /// Loads one page of projects.
  Future<RemoteData<PagedModel<ProjectModel>>> getProjects(ProjectQuery query) {
    return _requester.read<PagedModel<ProjectModel>>(
      ApiEndpoints.projects,
      query: <String, Object?>{
        'page': query.page,
        'pageSize': query.pageSize,
        if (query.search.isNotEmpty) 'q': query.search,
      },
      decoder: (Object? raw) =>
          PagedModel<ProjectModel>.fromJson(raw, ProjectModel.fromJson),
    );
  }

  /// Loads one project.
  Future<RemoteData<ProjectModel>> getProject(String id) =>
      _requester.read<ProjectModel>(
        ApiEndpoints.project(id),
        decoder: ProjectModel.fromJson,
      );
}
