import '../../models/assignee_model.dart';
import '../../models/json_reader.dart';
import '../../models/paged_model.dart';
import 'api_endpoints.dart';
import 'remote_outcome.dart';
import 'remote_requester.dart';

/// The users endpoint.
class AssigneeRemoteDataSource {
  /// Creates the data source.
  AssigneeRemoteDataSource(this._requester);

  /// Most people requested at once.
  static const int pageSize = 100;

  final RemoteRequester _requester;

  /// Loads the people available for assignment.
  Future<RemoteData<PagedModel<AssigneeModel>>> getAssignees() {
    return _requester.read<PagedModel<AssigneeModel>>(
      ApiEndpoints.users,
      query: const <String, Object?>{'page': 1, 'pageSize': pageSize},
      decoder: (Object? raw) => PagedModel<AssigneeModel>.fromJson(
        raw,
        (Object? item) => AssigneeModel.fromJson(asJson(item)),
      ),
    );
  }
}
