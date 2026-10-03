import '../entities/dashboard_summary.dart';
import '../entities/loaded.dart';
import '../repositories/dashboard_repository.dart';

/// Loads the dashboard figures.
class GetDashboardSummaryUseCase {
  /// Creates the use case.
  const GetDashboardSummaryUseCase(this._repository);

  final DashboardRepository _repository;

  /// Returns the summary.
  Future<Loaded<DashboardSummary>> call() => _repository.getSummary();
}
