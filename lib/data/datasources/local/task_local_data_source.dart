import '../../../domain/entities/sync_state.dart';
import '../../../domain/entities/task_query.dart';
import '../../models/task_model.dart';
import 'database/app_database.dart';
import 'pending_operation_ledger.dart';

/// A task as stored on this device.
class LocalTaskRecord {
  /// Creates a record.
  const LocalTaskRecord({
    required this.model,
    required this.syncState,
    required this.cachedAt,
  });

  /// The task data.
  final TaskModel model;

  /// Whether the task matches the server.
  final SyncState syncState;

  /// When the row was last written.
  final DateTime cachedAt;
}

/// One page of locally stored tasks.
class LocalTaskPage {
  /// Creates a page.
  const LocalTaskPage({required this.records, required this.total});

  /// Tasks on this page.
  final List<LocalTaskRecord> records;

  /// Number of tasks matching the query across all pages.
  final int total;

  /// The most recent time any returned row was written, if any.
  DateTime? get fetchedAt => records.isEmpty
      ? null
      : records.map((r) => r.cachedAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Local storage of tasks, including changes not yet sent to the server.
///
/// Controllers never use this directly; only repositories do.
abstract interface class TaskLocalDataSource implements PendingOperationLedger {
  /// Stores tasks received from the server.
  ///
  /// Tasks with local changes still waiting to be sent are left untouched so
  /// the user's edits are not overwritten.
  Future<void> saveRemote(Iterable<TaskModel> tasks, DateTime now);

  /// Returns tasks matching [query], hiding tasks with a pending deletion.
  ///
  /// With [pendingOnly] only tasks with unsent local changes are considered,
  /// and paging is ignored.
  Future<LocalTaskPage> query(TaskQuery query, {bool pendingOnly = false});

  /// Ids of tasks whose deletion is waiting to be sent.
  Future<Set<String>> pendingDeleteIds();

  /// Finds one task, including ones with a pending deletion.
  Future<LocalTaskRecord?> find(String id);

  /// Whether any task has ever been stored.
  Future<bool> hasData();

  /// Looks up the recorded change for the idempotency [key].
  Future<PendingOperation?> operation(String key);

  /// Records a create or update before it is sent.
  ///
  /// Stores [task] as pending and notes the change under [key].
  Future<void> beginChange({
    required String key,
    required PendingKind kind,
    required TaskModel task,
    required DateTime now,
  });

  /// Records a deletion before it is sent.
  Future<void> beginDelete({required String key, required String taskId});

  /// Marks the change under [key] as delivered.
  ///
  /// [serverTask] is the server's version of a created or updated task. A
  /// task created locally is replaced by it; a deleted task is removed.
  Future<void> completeChange(
    String key, {
    TaskModel? serverTask,
    required DateTime now,
  });

  /// Marks the change under [key] as rejected, keeping the task visible and
  /// flagged as failed.
  Future<void> failChange(String key);

  /// Undoes a change that could not be started, restoring [previous] or
  /// removing the task when there was none.
  Future<void> rollbackChange(String key, {LocalTaskRecord? previous});

  /// Forgets a task and every change recorded for it.
  Future<void> discard(String taskId);

  /// Removes all tasks and recorded changes.
  Future<void> clear();
}
