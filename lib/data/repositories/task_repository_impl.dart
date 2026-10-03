import '../../core/constants/app_strings.dart';
import '../../core/error/failure.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/assignee.dart';
import '../../domain/entities/loaded.dart';
import '../../domain/entities/paged_result.dart';
import '../../domain/entities/sync_state.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/requests/create_task_request.dart';
import '../../domain/requests/update_task_request.dart';
import '../datasources/local/database/app_database.dart';
import '../datasources/local/task_local_data_source.dart';
import '../datasources/remote/remote_outcome.dart';
import '../datasources/remote/task_remote_data_source.dart';
import '../models/paged_model.dart';
import '../models/task_model.dart';

/// [TaskRepository] that works with or without a connection.
///
/// Reads go to the server first and are copied into the local database. When
/// the server cannot be reached they are answered from the database and
/// flagged stale. Writes are recorded locally before they are sent, so they
/// show up immediately, survive a restart, and are delivered later by the
/// networking layer's offline queue if the device is offline.
class TaskRepositoryImpl implements TaskRepository {
  /// Creates the repository. [clock] is injectable for tests.
  TaskRepositoryImpl(
    this._remote,
    this._local,
    this._logger,
    this._ids, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Prefix of ids given to tasks that exist only on this device.
  static const String localIdPrefix = 'local-';

  final TaskRemoteDataSource _remote;
  final TaskLocalDataSource _local;
  final AppLogger _logger;
  final IdGenerator _ids;
  final DateTime Function() _clock;

  // ------------------------------------------------------------------ reads

  @override
  Future<Loaded<PagedResult<Task>>> getTasks(TaskQuery query) async {
    _logger.debug(
      LogTag.repository,
      'getTasks',
      context: <String, Object?>{'page': query.page, 'search': query.search},
    );
    try {
      final data = await _remote.getTasks(query);
      await _bestEffort(() => _local.saveRemote(data.value.items, _clock()));
      return Loaded(
        await _bestEffort(
          () => _withLocalChanges(query, data.value),
          orElse: () => data.value.toEntity((model) => model.toEntity()),
        ),
        fetchedAt: _clock(),
      );
    } on Failure catch (failure) {
      if (!_isUnreachable(failure)) rethrow;
      final saved = await _bestEffort<Loaded<PagedResult<Task>>?>(
        () => _savedTasks(query),
        orElse: () => null,
      );
      if (saved == null) rethrow;
      return saved;
    }
  }

  @override
  Future<Loaded<Task>> getTask(String id) async {
    _logger.debug(
      LogTag.repository,
      'getTask',
      context: <String, Object?>{'id': id},
    );
    final deleted = await _bestEffort(
      _local.pendingDeleteIds,
      orElse: () => <String>{},
    );
    if (deleted.contains(id)) throw const NotFoundFailure();
    final saved = await _bestEffort<LocalTaskRecord?>(
      () => _local.find(id),
      orElse: () => null,
    );
    if (id.startsWith(localIdPrefix) ||
        (saved != null && saved.syncState != SyncState.synced)) {
      if (saved == null) throw const NotFoundFailure();
      return Loaded(_entity(saved));
    }
    try {
      final data = await _remote.getTask(id);
      await _bestEffort(() => _local.saveRemote([data.value], _clock()));
      return Loaded(data.value.toEntity(), fetchedAt: _clock());
    } on Failure catch (failure) {
      if (!_isUnreachable(failure) || saved == null) rethrow;
      return Loaded(_entity(saved), isStale: true, fetchedAt: saved.cachedAt);
    }
  }

  // ----------------------------------------------------------------- writes

  @override
  Future<Task> createTask(CreateTaskRequest request) async {
    _logger.debug(LogTag.repository, 'createTask');
    final key = _ids.next();
    final optimistic = _pendingTask(request, '$localIdPrefix$key');
    await _local.beginChange(
      key: key,
      kind: PendingKind.create,
      task: TaskModel.fromEntity(optimistic),
      now: _clock(),
    );
    try {
      return switch (await _remote.createTask(request, key)) {
        Applied<TaskModel>(:final value) => await _delivered(key, value),
        Queued<TaskModel>() => optimistic,
      };
    } on Failure {
      await _local.rollbackChange(key);
      rethrow;
    }
  }

  @override
  Future<Task> updateTask(String id, UpdateTaskRequest request) async {
    _logger.debug(
      LogTag.repository,
      'updateTask',
      context: <String, Object?>{'id': id},
    );
    _requireOnServer(id);
    final previous = await _local.find(id) ?? await _fetchIntoLocal(id);
    final key = _ids.next();
    final optimistic = _applyUpdate(_entity(previous), request);
    await _local.beginChange(
      key: key,
      kind: PendingKind.update,
      task: TaskModel.fromEntity(optimistic),
      now: _clock(),
    );
    try {
      return switch (await _remote.updateTask(id, request, key)) {
        Applied<TaskModel>(:final value) => await _delivered(key, value),
        Queued<TaskModel>() => optimistic,
      };
    } on Failure {
      await _local.rollbackChange(key, previous: previous);
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _logger.debug(
      LogTag.repository,
      'deleteTask',
      context: <String, Object?>{'id': id},
    );
    _requireOnServer(id);
    final previous = await _local.find(id);
    final key = _ids.next();
    await _local.beginDelete(key: key, taskId: id);
    try {
      final outcome = await _remote.deleteTask(id, key);
      if (outcome is Applied<void>) {
        await _local.completeChange(key, now: _clock());
      }
    } on NotFoundFailure {
      await _local.completeChange(key, now: _clock());
    } on Failure {
      await _local.rollbackChange(key, previous: previous);
      rethrow;
    }
  }

  @override
  Future<void> discardLocalChanges(String id) async {
    _logger.debug(
      LogTag.repository,
      'discardLocalChanges',
      context: <String, Object?>{'id': id},
    );
    await _local.discard(id);
    if (id.startsWith(localIdPrefix)) return;
    try {
      final data = await _remote.getTask(id);
      await _local.saveRemote([data.value], _clock());
    } on Failure {
      // Offline: the server version is restored by the next successful load.
    }
  }

  // ---------------------------------------------------------------- helpers

  /// Runs a local storage step whose failure must not stop the screen.
  ///
  /// A cache that cannot be written or read only costs offline support, so the
  /// failure is logged and [orElse] (or nothing) is used instead.
  Future<T> _bestEffort<T>(
    Future<T> Function() action, {
    T Function()? orElse,
  }) async {
    try {
      return await action();
    } on CacheFailure catch (failure) {
      _logger.warning(
        LogTag.repository,
        'local storage unavailable',
        error: failure,
      );
      if (orElse != null) return orElse();
      return null as T;
    }
  }

  /// Tasks that exist only on this device cannot be changed until they sync,
  /// because the server does not know their id yet.
  void _requireOnServer(String id) {
    if (id.startsWith(localIdPrefix)) {
      throw const OfflineFailure(message: AppStrings.taskPendingSync);
    }
  }

  bool _isUnreachable(Failure failure) =>
      failure is NetworkFailure ||
      failure is OfflineFailure ||
      failure is TimeoutFailure ||
      failure is ServerFailure;

  Task _entity(LocalTaskRecord record) =>
      record.model.toEntity().copyWith(syncState: record.syncState);

  Future<Task> _delivered(String key, TaskModel serverTask) async {
    await _local.completeChange(key, serverTask: serverTask, now: _clock());
    return serverTask.toEntity();
  }

  Future<LocalTaskRecord> _fetchIntoLocal(String id) async {
    final data = await _remote.getTask(id);
    await _local.saveRemote([data.value], _clock());
    return (await _local.find(id))!;
  }

  /// Answers a list request from the database, or null when nothing has ever
  /// been saved.
  Future<Loaded<PagedResult<Task>>?> _savedTasks(TaskQuery query) async {
    if (!await _local.hasData()) return null;
    final page = await _local.query(query);
    return Loaded(
      PagedResult<Task>(
        items: page.records.map(_entity).toList(),
        page: query.page,
        pageSize: query.pageSize,
        total: page.total,
      ),
      isStale: true,
      fetchedAt: page.fetchedAt,
    );
  }

  /// Overlays unsent local changes on a page received from the server: edited
  /// tasks show the local version, deleted tasks disappear, and tasks created
  /// on this device appear at the top of the first page.
  Future<PagedResult<Task>> _withLocalChanges(
    TaskQuery query,
    PagedModel<TaskModel> remote,
  ) async {
    final pending = await _local.query(query, pendingOnly: true);
    final deleted = await _local.pendingDeleteIds();
    final pendingById = {for (final r in pending.records) r.model.id: r};
    final remoteIds = remote.items.map((t) => t.id).toSet();

    final created = query.page == 1
        ? pending.records
              .where((r) => !remoteIds.contains(r.model.id))
              .where((r) => r.model.id.startsWith(localIdPrefix))
              .map(_entity)
              .toList()
        : <Task>[];
    final fromServer = <Task>[];
    var removed = 0;
    for (final model in remote.items) {
      if (deleted.contains(model.id)) {
        removed++;
        continue;
      }
      final local = pendingById[model.id];
      fromServer.add(local == null ? model.toEntity() : _entity(local));
    }
    return PagedResult<Task>(
      items: <Task>[...created, ...fromServer],
      page: remote.page,
      pageSize: remote.pageSize,
      total: remote.total + created.length - removed,
    );
  }

  Task _pendingTask(CreateTaskRequest request, String localId) {
    final now = _clock();
    final assigneeId = request.assigneeId;
    return Task(
      id: localId,
      title: request.title,
      description: request.description,
      status: TaskStatus.todo,
      priority: request.priority,
      projectId: request.projectId,
      assignee: assigneeId == null ? null : Assignee(id: assigneeId, name: ''),
      dueDate: request.dueDate,
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.pending,
    );
  }

  Task _applyUpdate(Task current, UpdateTaskRequest request) {
    final assigneeId = request.assigneeId;
    final assignee = assigneeId == null
        ? current.assignee
        : Assignee(
            id: assigneeId,
            name: current.assignee?.id == assigneeId
                ? current.assignee!.name
                : '',
          );
    return current.copyWith(
      title: request.title,
      description: request.description,
      status: request.status,
      priority: request.priority,
      assignee: assignee,
      dueDate: request.dueDate,
      clearDueDate: request.clearDueDate,
      updatedAt: _clock(),
      syncState: SyncState.pending,
    );
  }
}
