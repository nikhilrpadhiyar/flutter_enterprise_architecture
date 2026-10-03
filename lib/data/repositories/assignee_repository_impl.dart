import '../../core/logging/app_logger.dart';
import '../../domain/entities/assignee.dart';
import '../../domain/entities/loaded.dart';
import '../../domain/repositories/assignee_repository.dart';
import '../datasources/remote/assignee_remote_data_source.dart';

/// [AssigneeRepository] backed by the users endpoint. Offline reads use the
/// networking layer's response cache.
class AssigneeRepositoryImpl implements AssigneeRepository {
  /// Creates the repository.
  AssigneeRepositoryImpl(this._remote, this._logger);

  final AssigneeRemoteDataSource _remote;
  final AppLogger _logger;

  @override
  Future<Loaded<List<Assignee>>> getAssignees() async {
    _logger.debug(LogTag.repository, 'getAssignees');
    final data = await _remote.getAssignees();
    return Loaded(
      data.value.items.map((model) => model.toEntity()).toList(),
      isStale: data.fromCache,
    );
  }
}
