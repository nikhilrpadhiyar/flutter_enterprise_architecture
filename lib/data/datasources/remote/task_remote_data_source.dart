import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../domain/entities/task_query.dart';
import '../../../domain/entities/task_sort.dart';
import '../../../domain/requests/create_task_request.dart';
import '../../../domain/requests/update_task_request.dart';
import '../../models/paged_model.dart';
import '../../models/requests/request_bodies.dart';
import '../../models/task_model.dart';
import 'api_endpoints.dart';
import 'remote_outcome.dart';
import 'remote_requester.dart';

/// Task endpoints.
///
/// Reads bypass the networking layer's response cache because the local
/// database is the offline source for tasks. Writes are queued by the
/// networking layer when the device is offline, so each carries an
/// idempotency key, chosen by the repository, that makes a later replay safe
/// and links the request to its local record.
class TaskRemoteDataSource {
  /// Creates the data source.
  TaskRemoteDataSource(this._requester);

  final RemoteRequester _requester;

  /// Loads one page of tasks matching [query].
  Future<RemoteData<PagedModel<TaskModel>>> getTasks(TaskQuery query) {
    return _requester.read<PagedModel<TaskModel>>(
      ApiEndpoints.tasks,
      query: queryParameters(query),
      decoder: (Object? raw) =>
          PagedModel<TaskModel>.fromJson(raw, TaskModel.fromJson),
      policy: fnp.CachePolicy.networkOnly,
    );
  }

  /// Loads one task.
  Future<RemoteData<TaskModel>> getTask(String id) =>
      _requester.read<TaskModel>(
        ApiEndpoints.task(id),
        decoder: TaskModel.fromJson,
        policy: fnp.CachePolicy.networkOnly,
      );

  /// Creates a task. [idempotencyKey] identifies this attempt.
  Future<MutationOutcome<TaskModel>> createTask(
    CreateTaskRequest request,
    String idempotencyKey,
  ) => _requester.writeQueued<TaskModel>(
    fnp.HttpMethod.post,
    ApiEndpoints.tasks,
    body: RequestBodies.createTask(request),
    decoder: TaskModel.fromJson,
    idempotencyKey: idempotencyKey,
  );

  /// Updates a task. [idempotencyKey] identifies this attempt.
  Future<MutationOutcome<TaskModel>> updateTask(
    String id,
    UpdateTaskRequest request,
    String idempotencyKey,
  ) => _requester.writeQueued<TaskModel>(
    fnp.HttpMethod.patch,
    ApiEndpoints.task(id),
    body: RequestBodies.updateTask(request),
    decoder: TaskModel.fromJson,
    idempotencyKey: idempotencyKey,
  );

  /// Deletes a task. [idempotencyKey] identifies this attempt.
  Future<MutationOutcome<void>> deleteTask(String id, String idempotencyKey) =>
      _requester.writeQueuedVoid(
        fnp.HttpMethod.delete,
        ApiEndpoints.task(id),
        idempotencyKey: idempotencyKey,
      );

  /// Converts [query] to the API's query string parameters.
  static Map<String, Object?> queryParameters(TaskQuery query) {
    return <String, Object?>{
      'page': query.page,
      'pageSize': query.pageSize,
      if (query.search.isNotEmpty) 'q': query.search,
      if (query.statuses.isNotEmpty)
        'status': (query.statuses.map((s) => s.name).toList()..sort()).join(
          ',',
        ),
      if (query.priorities.isNotEmpty)
        'priority': (query.priorities.map((p) => p.name).toList()..sort()).join(
          ',',
        ),
      if (query.projectId != null) 'projectId': query.projectId,
      'sort': _sortValue(query.sort),
    };
  }

  static String _sortValue(TaskSort sort) => switch (sort) {
    TaskSort.dueDateAscending => 'dueDate',
    TaskSort.dueDateDescending => '-dueDate',
    TaskSort.priority => 'priority',
    TaskSort.recentlyUpdated => '-updatedAt',
  };
}
