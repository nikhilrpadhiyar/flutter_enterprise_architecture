import '../entities/dashboard_summary.dart';
import '../entities/loaded.dart';

/// Aggregated figures for the dashboard.
abstract interface class DashboardRepository {
  /// Loads the summary, falling back to saved data when offline.
  Future<Loaded<DashboardSummary>> getSummary();
}
