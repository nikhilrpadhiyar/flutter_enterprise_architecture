import 'dart:convert';

import '../../models/json_reader.dart';
import '../../models/user_model.dart';
import 'database/app_database.dart';
import 'local_guard.dart';
import 'session_local_data_source.dart';

/// [SessionLocalDataSource] backed by the app database.
class SessionLocalDataSourceImpl implements SessionLocalDataSource {
  /// Creates the data source.
  SessionLocalDataSourceImpl(this._db);

  static const String _userKey = 'session_user';

  final AppDatabase _db;

  @override
  Future<UserModel?> readUser() => guardLocal(() async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.key.equals(_userKey))).getSingleOrNull();
    if (row == null) return null;
    return UserModel.fromJson(asJson(jsonDecode(row.value)));
  });

  @override
  Future<void> saveUser(UserModel user) => guardLocal(() async {
    await _db
        .into(_db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion.insert(
            key: _userKey,
            value: jsonEncode(user.toJson()),
          ),
        );
  });

  @override
  Future<void> clear() => guardLocal(() async {
    await (_db.delete(
      _db.keyValues,
    )..where((t) => t.key.equals(_userKey))).go();
  });
}
