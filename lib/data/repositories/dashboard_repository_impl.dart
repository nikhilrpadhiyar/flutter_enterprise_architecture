import '../../core/logging/app_logger.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/loaded.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/remote/dashboard_remote_data_source.dart';

/// [DashboardRepository] backed by the remote dashboard endpoint.
class DashboardRepositoryImpl implements DashboardRepository {
  /// Creates the repository.
  DashboardRepositoryImpl(this._remote, this._logger);

  final DashboardRemoteDataSource _remote;
  final AppLogger _logger;

  @override
  Future<Loaded<DashboardSummary>> getSummary() async {
    _logger.debug(LogTag.repository, 'getSummary');
    final data = await _remote.getSummary();
    return Loaded(data.value.toEntity(), isStale: data.fromCache);
  }
}
