import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/sync_state.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/entities/task_sort.dart';
import '../../models/json_reader.dart';
import '../../models/task_model.dart';
import 'database/app_database.dart';
import 'local_guard.dart';
import 'task_local_data_source.dart';

/// [TaskLocalDataSource] backed by the app database.
class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  /// Creates the data source.
  TaskLocalDataSourceImpl(this._db);

  static const String _likeEscape = r'\';

  final AppDatabase _db;

  /// Escapes the characters that `LIKE` treats as wildcards, so search text
  /// is always matched literally.
  static String _escapeLike(String text) => text
      .replaceAll(_likeEscape, '$_likeEscape$_likeEscape')
      .replaceAll('%', '$_likeEscape%')
      .replaceAll('_', '${_likeEscape}_');

  @override
  Future<void> saveRemote(Iterable<TaskModel> tasks, DateTime now) =>
      guardLocal(() async {
        final models = tasks.toList();
        if (models.isEmpty) return;
        await _db.transaction(() async {
          final protected = await _protectedIds(models.map((m) => m.id));
          await _db.batch((batch) {
            batch.insertAllOnConflictUpdate(_db.localTasks, [
              for (final model in models)
                if (!protected.contains(model.id))
                  _companion(model, SyncState.synced, now),
            ]);
          });
        });
      });

  @override
  Future<LocalTaskPage> query(TaskQuery query, {bool pendingOnly = false}) =>
      guardLocal(() async {
        final filter = _filter(query, pendingOnly);
        final countExpression = _db.localTasks.id.count();
        final total =
            await (_db.selectOnly(_db.localTasks)
                  ..addColumns([countExpression])
                  ..where(filter))
                .map((row) => row.read(countExpression) ?? 0)
                .getSingle();

        final select = _db.select(_db.localTasks)
          ..where((_) => filter)
          ..orderBy(_ordering(query.sort));
        if (!pendingOnly) {
          select.limit(
            query.pageSize,
            offset: (query.page - 1) * query.pageSize,
          );
        }
        final rows = await select.get();
        return LocalTaskPage(records: rows.map(_record).toList(), total: total);
      });

  @override
  Future<Set<String>> pendingDeleteIds() => guardLocal(() async {
    final rows = await (_db.select(
      _db.localTasks,
    )..where((t) => t.pendingDelete.equals(true))).get();
    return rows.map((r) => r.id).toSet();
  });

  @override
  Future<LocalTaskRecord?> find(String id) => guardLocal(() async {
    final row = await (_db.select(
      _db.localTasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _record(row);
  });

  @override
  Future<bool> hasData() => guardLocal(() async {
    final row = await (_db.select(_db.localTasks)..limit(1)).getSingleOrNull();
    return row != null;
  });

  @override
  Future<PendingOperation?> operation(String key) {
    return guardLocal(
      () => (_db.select(
        _db.pendingOperations,
      )..where((t) => t.key.equals(key))).getSingleOrNull(),
    );
  }

  @override
  Future<bool> contains(String key) async => await operation(key) != null;

  @override
  Future<void> beginChange({
    required String key,
    required PendingKind kind,
    required TaskModel task,
    required DateTime now,
  }) {
    return guardLocal(
      () => _db.transaction(() async {
        await _db
            .into(_db.localTasks)
            .insertOnConflictUpdate(_companion(task, SyncState.pending, now));
        await _recordOperation(key, kind, task.id, now);
      }),
    );
  }

  @override
  Future<void> beginDelete({required String key, required String taskId}) {
    return guardLocal(
      () => _db.transaction(() async {
        await (_db.update(
          _db.localTasks,
        )..where((t) => t.id.equals(taskId))).write(
          const LocalTasksCompanion(
            pendingDelete: Value(true),
            syncState: Value(SyncState.pending),
          ),
        );
        await _recordOperation(key, PendingKind.delete, taskId, DateTime.now());
      }),
    );
  }

  @override
  Future<void> completeChange(
    String key, {
    TaskModel? serverTask,
    required DateTime now,
  }) {
    return guardLocal(
      () => _db.transaction(() async {
        final operation = await this.operation(key);
        if (operation == null) return;
        await _deleteRow(operation.taskId);
        if (operation.kind != PendingKind.delete && serverTask != null) {
          await _db
              .into(_db.localTasks)
              .insertOnConflictUpdate(
                _companion(serverTask, SyncState.synced, now),
              );
        }
        await _deleteOperation(key);
      }),
    );
  }

  @override
  Future<void> failChange(String key) {
    return guardLocal(
      () => _db.transaction(() async {
        final operation = await this.operation(key);
        if (operation == null) return;
        await (_db.update(
          _db.localTasks,
        )..where((t) => t.id.equals(operation.taskId))).write(
          const LocalTasksCompanion(
            pendingDelete: Value(false),
            syncState: Value(SyncState.failed),
          ),
        );
        await _deleteOperation(key);
      }),
    );
  }

  @override
  Future<void> rollbackChange(String key, {LocalTaskRecord? previous}) {
    return guardLocal(
      () => _db.transaction(() async {
        final operation = await this.operation(key);
        if (operation == null) return;
        if (previous == null) {
          await _deleteRow(operation.taskId);
        } else {
          await _db
              .into(_db.localTasks)
              .insertOnConflictUpdate(
                _companion(
                  previous.model,
                  previous.syncState,
                  previous.cachedAt,
                ),
              );
        }
        await _deleteOperation(key);
      }),
    );
  }

  @override
  Future<void> discard(String taskId) {
    return guardLocal(
      () => _db.transaction(() async {
        await _deleteRow(taskId);
        await (_db.delete(
          _db.pendingOperations,
        )..where((t) => t.taskId.equals(taskId))).go();
      }),
    );
  }

  @override
  Future<void> clear() {
    return guardLocal(
      () => _db.transaction(() async {
        await _db.delete(_db.localTasks).go();
        await _db.delete(_db.pendingOperations).go();
      }),
    );
  }

  // ---------------------------------------------------------------- helpers

  Future<Set<String>> _protectedIds(Iterable<String> ids) async {
    final rows =
        await (_db.select(_db.localTasks)..where(
              (t) =>
                  t.id.isIn(ids.toList()) &
                  t.syncState.equalsValue(SyncState.synced).not(),
            ))
            .get();
    return rows.map((r) => r.id).toSet();
  }

  Expression<bool> _filter(TaskQuery query, bool pendingOnly) {
    final t = _db.localTasks;
    var filter = t.pendingDelete.equals(false);
    if (pendingOnly) {
      filter = filter & t.syncState.equalsValue(SyncState.synced).not();
    }
    final search = query.search.trim();
    if (search.isNotEmpty) {
      final pattern = '%${_escapeLike(search)}%';
      filter =
          filter &
          (t.title.like(pattern, escapeChar: _likeEscape) |
              t.description.like(pattern, escapeChar: _likeEscape));
    }
    if (query.statuses.isNotEmpty) {
      filter = filter & t.status.isIn(query.statuses.map((s) => s.name));
    }
    if (query.priorities.isNotEmpty) {
      filter = filter & t.priority.isIn(query.priorities.map((p) => p.name));
    }
    final projectId = query.projectId;
    if (projectId != null) filter = filter & t.projectId.equals(projectId);
    return filter;
  }

  List<OrderingTerm Function($LocalTasksTable)> _ordering(TaskSort sort) {
    OrderingTerm tieBreak($LocalTasksTable t) => OrderingTerm.asc(t.id);
    return switch (sort) {
      TaskSort.dueDateAscending => [
        (t) => OrderingTerm.asc(t.dueDate.isNull()),
        (t) => OrderingTerm.asc(t.dueDate),
        tieBreak,
      ],
      TaskSort.dueDateDescending => [
        (t) => OrderingTerm.asc(t.dueDate.isNull()),
        (t) => OrderingTerm.desc(t.dueDate),
        tieBreak,
      ],
      TaskSort.priority => [
        (t) => OrderingTerm.desc(t.priorityRank),
        (t) => OrderingTerm.desc(t.updatedAt),
        tieBreak,
      ],
      TaskSort.recentlyUpdated => [
        (t) => OrderingTerm.desc(t.updatedAt),
        tieBreak,
      ],
    };
  }

  LocalTasksCompanion _companion(
    TaskModel model,
    SyncState syncState,
    DateTime now,
  ) {
    return LocalTasksCompanion.insert(
      id: model.id,
      projectId: model.projectId,
      title: model.title,
      description: model.description,
      status: model.status.name,
      priority: model.priority.name,
      priorityRank: model.priority.index,
      dueDate: Value(model.dueDate?.toUtc().millisecondsSinceEpoch),
      updatedAt: model.updatedAt.toUtc().millisecondsSinceEpoch,
      syncState: syncState,
      pendingDelete: const Value(false),
      cachedAt: now.toUtc().millisecondsSinceEpoch,
      json: jsonEncode(model.toJson()),
    );
  }

  LocalTaskRecord _record(LocalTask row) {
    return LocalTaskRecord(
      model: TaskModel.fromJson(asJson(jsonDecode(row.json))),
      syncState: row.syncState,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(row.cachedAt, isUtc: true),
    );
  }

  Future<void> _recordOperation(
    String key,
    PendingKind kind,
    String taskId,
    DateTime now,
  ) {
    return _db
        .into(_db.pendingOperations)
        .insertOnConflictUpdate(
          PendingOperationsCompanion.insert(
            key: key,
            kind: kind,
            taskId: taskId,
            createdAt: now.toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> _deleteRow(String taskId) =>
      (_db.delete(_db.localTasks)..where((t) => t.id.equals(taskId))).go();

  Future<void> _deleteOperation(String key) =>
      (_db.delete(_db.pendingOperations)..where((t) => t.key.equals(key))).go();
}
