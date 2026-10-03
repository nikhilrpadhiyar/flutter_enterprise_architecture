import 'package:drift/drift.dart';

import '../../../../domain/entities/sync_state.dart';

part 'app_database.g.dart';

/// Kind of change waiting to be sent to the server.
enum PendingKind {
  /// A task created on this device.
  create,

  /// An edit to an existing task.
  update,

  /// A deletion.
  delete,
}

/// Tasks seen by this device, plus tasks created or changed locally.
///
/// Filterable fields are real columns so lists can be queried offline. The
/// full task, including attachments and activity, is kept in [json].
class LocalTasks extends Table {
  /// Server id, or `local-...` for a task not yet created on the server.
  TextColumn get id => text()();

  /// Owning project id.
  TextColumn get projectId => text()();

  /// Task title.
  TextColumn get title => text()();

  /// Task description.
  TextColumn get description => text()();

  /// Status name.
  TextColumn get status => text()();

  /// Priority name.
  TextColumn get priority => text()();

  /// Numeric priority for sorting.
  IntColumn get priorityRank => integer()();

  /// Deadline, milliseconds since the epoch (UTC).
  IntColumn get dueDate => integer().nullable()();

  /// Last change, milliseconds since the epoch (UTC).
  IntColumn get updatedAt => integer()();

  /// Whether the row matches the server.
  IntColumn get syncState => intEnum<SyncState>()();

  /// Whether a deletion is waiting to be sent.
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();

  /// When the row was last written, milliseconds since the epoch (UTC).
  IntColumn get cachedAt => integer()();

  /// The whole task as API JSON.
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Changes waiting to be sent, keyed by the idempotency key of the request
/// that carries them. Doubles as the record of which queued requests belong
/// to the signed-in user.
class PendingOperations extends Table {
  /// Idempotency key of the queued request.
  TextColumn get key => text()();

  /// What the change does.
  TextColumn get kind => textEnum<PendingKind>()();

  /// The task it changes.
  TextColumn get taskId => text()();

  /// When it was recorded, milliseconds since the epoch (UTC).
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Small string settings, such as the saved session user.
class KeyValues extends Table {
  /// Setting name.
  TextColumn get key => text()();

  /// Setting value.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The app's local SQLite database.
@DriftDatabase(tables: [LocalTasks, PendingOperations, KeyValues])
class AppDatabase extends _$AppDatabase {
  /// Opens the database over [executor].
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
