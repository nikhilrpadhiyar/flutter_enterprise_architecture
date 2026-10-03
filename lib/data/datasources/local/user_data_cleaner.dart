import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import 'session_local_data_source.dart';
import 'task_local_data_source.dart';

/// Removes everything stored for the current user on this device.
///
/// Used when signing out and when a different user signs in, so one
/// account's data is never visible to another.
abstract interface class UserDataCleaner {
  /// Deletes saved tasks, recorded offline changes, the saved user and the
  /// networking layer's response cache.
  Future<void> clear();
}

/// [UserDataCleaner] over the app's local data sources and response cache.
class LocalUserDataCleaner implements UserDataCleaner {
  /// Creates the cleaner.
  LocalUserDataCleaner(this._tasks, this._session, this._responseCache);

  final TaskLocalDataSource _tasks;
  final SessionLocalDataSource _session;
  final fnp.CacheStore _responseCache;

  @override
  Future<void> clear() async {
    await _tasks.clear();
    await _session.clear();
    await _responseCache.clear();
  }
}
