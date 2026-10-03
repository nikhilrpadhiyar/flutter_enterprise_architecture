import '../../models/dashboard_summary_model.dart';
import 'api_endpoints.dart';
import 'remote_outcome.dart';
import 'remote_requester.dart';

/// Dashboard endpoint.
class DashboardRemoteDataSource {
  /// Creates the data source.
  DashboardRemoteDataSource(this._requester);

  final RemoteRequester _requester;

  /// Loads the dashboard summary.
  Future<RemoteData<DashboardSummaryModel>> getSummary() =>
      _requester.read<DashboardSummaryModel>(
        ApiEndpoints.dashboardSummary,
        decoder: DashboardSummaryModel.fromJson,
      );
}
