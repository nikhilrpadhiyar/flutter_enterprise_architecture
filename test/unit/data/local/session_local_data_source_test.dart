import 'dart:typed_data';

import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/session_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/user_data_cleaner.dart';
import 'package:flutter_enterprise_architecture/data/models/user_model.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/task_models.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SessionLocalDataSourceImpl session;

  setUp(() {
    db = createTestDatabase();
    session = SessionLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  test('has no user at first', () async {
    expect(await session.readUser(), isNull);
  });

  test('saves and reads the user', () async {
    await session.saveUser(UserModel.fromJson(userJson()));
    final user = await session.readUser();
    expect(user?.id, 'u1');
    expect(user?.email, 'ada@example.com');
    expect(user?.phone, isNull);
  });

  test('saving again replaces the user', () async {
    await session.saveUser(UserModel.fromJson(userJson()));
    await session.saveUser(UserModel.fromJson(userJson(id: 'u2')));
    expect((await session.readUser())?.id, 'u2');
  });

  test('clear forgets the user', () async {
    await session.saveUser(UserModel.fromJson(userJson()));
    await session.clear();
    expect(await session.readUser(), isNull);
  });

  test('the cleaner removes tasks, the user and cached responses', () async {
    final tasks = TaskLocalDataSourceImpl(db);
    final cache = fnp.MemoryCacheStore();
    await cache.write(
      'GET /x',
      fnp.CacheEntry(
        statusCode: 200,
        headers: const <String, List<String>>{},
        bodyBytes: Uint8List(0),
        storedAt: DateTime.utc(2026),
        ttl: const Duration(minutes: 5),
      ),
    );
    await tasks.saveRemote([taskModel()], DateTime.utc(2026));
    await session.saveUser(UserModel.fromJson(userJson()));

    await LocalUserDataCleaner(tasks, session, cache).clear();

    expect(await tasks.hasData(), isFalse);
    expect(await session.readUser(), isNull);
    expect(await cache.read('GET /x'), isNull);
  });
}
