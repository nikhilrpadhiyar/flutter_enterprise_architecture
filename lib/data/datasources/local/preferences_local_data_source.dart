import 'database/app_database.dart';
import 'local_guard.dart';

/// Local storage of device settings, kept apart from user data so signing
/// out does not reset them.
abstract interface class PreferencesLocalDataSource {
  /// Reads the setting stored under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);
}

/// [PreferencesLocalDataSource] backed by the app database.
class PreferencesLocalDataSourceImpl implements PreferencesLocalDataSource {
  /// Creates the data source.
  PreferencesLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) => guardLocal(() async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  });

  @override
  Future<void> write(String key, String value) => guardLocal(() async {
    await _db
        .into(_db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion.insert(key: key, value: value),
        );
  });
}
