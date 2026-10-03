import '../entities/assignee.dart';
import '../entities/loaded.dart';

/// The people tasks can be assigned to.
abstract interface class AssigneeRepository {
  /// Loads the people available for assignment, falling back to saved data
  /// when offline.
  Future<Loaded<List<Assignee>>> getAssignees();
}
