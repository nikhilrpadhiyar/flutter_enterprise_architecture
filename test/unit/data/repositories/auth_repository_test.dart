import 'dart:typed_data';

import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/profile_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/remote/sync_remote_data_source.dart';
import 'package:flutter_enterprise_architecture/data/models/user_model.dart';
import 'package:flutter_enterprise_architecture/data/repositories/auth_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/profile_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/entities/user_role.dart';
import 'package:flutter_enterprise_architecture/domain/requests/register_request.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';
import '../../../helpers/task_models.dart';
import '../../../helpers/test_network.dart';

void main() {
  late TestNetwork net;
  late AuthRepositoryImpl repository;
  final fixedNow = DateTime.utc(2026, 10, 2, 12);

  setUp(() {
    net = TestNetwork();
    repository = AuthRepositoryImpl(
      AuthRemoteDataSource(net.requester, net.tokens, clock: () => fixedNow),
      net.sessionLocal,
      net.cleaner,
      SyncRemoteDataSource(net.client),
      net.expiry,
      net.logger,
    );
  });

  tearDown(() => net.dispose());

  String? authorizationOf(fnp.RecordedCall call) => call.headers.entries
      .where((e) => e.key.toLowerCase() == 'authorization')
      .map((e) => e.value)
      .firstOrNull;

  group('login', () {
    test('returns the user and stores tokens with their expiry', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.json(sessionJson()),
      );

      final user = await repository.login(
        email: 'ada@example.com',
        password: 'password1',
      );

      expect(user.name, 'Ada Lovelace');
      expect(user.role, UserRole.member);
      final stored = await net.tokens.read();
      expect(stored?.accessToken, 'access-1');
      expect(stored?.refreshToken, 'refresh-1');
      expect(stored?.expiresAt, fixedNow.add(const Duration(seconds: 900)));
    });

    test('sends the credentials without an authorization header', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.json(sessionJson()),
      );

      await repository.login(email: 'ada@example.com', password: 'password1');

      final call = net.adapter.callsTo('/v1/auth/login').single;
      expect(call.bodyJson, <String, Object?>{
        'email': 'ada@example.com',
        'password': 'password1',
      });
      expect(authorizationOf(call), isNull);
    });

    test('wrong credentials become AuthenticationFailure', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) =>
            fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401),
      );

      await expectLater(
        repository.login(email: 'a@b.co', password: 'bad'),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(await net.tokens.read(), isNull);
    });

    test('server field errors become ValidationFailure', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/register'),
        (call) => fnp.MockResponse.json(
          errorJson(
            'validation_failed',
            fields: <String, String>{'email': 'Taken'},
          ),
          statusCode: 422,
        ),
      );

      await expectLater(
        repository.register(
          const RegisterRequest(
            name: 'Ada',
            email: 'ada@example.com',
            password: 'password1',
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors,
            'fieldErrors',
            <String, String>{'email': 'Taken'},
          ),
        ),
      );
    });

    test('an unreachable server becomes NetworkFailure', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );
      await expectLater(
        repository.login(email: 'a@b.co', password: 'pw'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('logout', () {
    test('clears tokens after telling the server', () async {
      await net.signIn();
      net.adapter.onPost(
        TestNetwork.path('auth/logout'),
        (call) => fnp.MockResponse.bytes(Uint8List(0), statusCode: 204),
      );

      await repository.logout();

      expect(net.adapter.callsTo('/v1/auth/logout'), hasLength(1));
      expect(await net.tokens.read(), isNull);
    });

    test('still signs out locally when the server call fails', () async {
      await net.signIn();
      net.adapter.onPost(
        TestNetwork.path('auth/logout'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );

      await repository.logout();

      expect(await net.tokens.read(), isNull);
    });
  });

  group('restoreSession', () {
    test('returns null without calling the server when signed out', () async {
      expect(await repository.restoreSession(), isNull);
      expect(net.adapter.capturedRequests, isEmpty);
    });

    test('loads the user for a saved session', () async {
      await net.signIn();
      net.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.json(userJson()),
      );

      final user = await repository.restoreSession();

      expect(user?.email, 'ada@example.com');
    });
  });

  group('token refresh', () {
    test(
      'refreshes an expired token once and retries with the new one',
      () async {
        await net.signIn(validFor: const Duration(minutes: -5));
        net.adapter
          ..onPost(
            TestNetwork.path('auth/refresh'),
            (call) => fnp.MockResponse.json(<String, Object?>{
              'accessToken': 'access-2',
              'refreshToken': 'refresh-2',
              'expiresIn': 900,
            }),
          )
          ..onGet(
            TestNetwork.path('profile'),
            (call) => fnp.MockResponse.json(userJson()),
          );

        final profile = await ProfileRepositoryImpl(
          ProfileRemoteDataSource(net.requester),
          net.sessionLocal,
          net.logger,
        ).getProfile();

        expect(profile.data.id, 'u1');
        expect(net.adapter.callsTo('/v1/auth/refresh'), hasLength(1));
        expect(
          authorizationOf(net.adapter.callsTo('/v1/profile').single),
          'Bearer access-2',
        );
        expect((await net.tokens.read())?.accessToken, 'access-2');
      },
    );

    test('a failed refresh signs the user out and notifies the app', () async {
      await net.signIn(validFor: const Duration(minutes: -5));
      net.adapter.onPost(
        TestNetwork.path('auth/refresh'),
        (call) =>
            fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401),
      );
      final expired = net.expiry.onExpired.first;

      await expectLater(
        ProfileRepositoryImpl(
          ProfileRemoteDataSource(net.requester),
          net.sessionLocal,
          net.logger,
        ).getProfile(),
        throwsA(isA<AuthenticationFailure>()),
      );

      await expired.timeout(const Duration(seconds: 2));
      expect(await net.tokens.read(), isNull);
      expect(net.adapter.callsTo('/v1/profile'), isEmpty);
    });

    test(
      'restoreSession returns null when the saved session is rejected',
      () async {
        await net.signIn(validFor: const Duration(minutes: -5));
        net.adapter.onPost(
          TestNetwork.path('auth/refresh'),
          (call) =>
              fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401),
        );

        expect(await repository.restoreSession(), isNull);
        expect(await net.tokens.read(), isNull);
      },
    );
  });

  group('local storage of the session', () {
    test('login remembers the user for offline start', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.json(sessionJson()),
      );
      await repository.login(email: 'ada@example.com', password: 'Password1');

      final saved = await net.sessionLocal.readUser();
      expect(saved?.email, 'ada@example.com');
    });

    test('signing in as the same user keeps their saved data', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.json(sessionJson()),
      );
      await net.sessionLocal.saveUser(UserModel.fromJson(userJson()));
      await net.taskLocal.saveRemote([taskModel()], fixedNow);

      await repository.login(email: 'ada@example.com', password: 'Password1');

      expect(await net.taskLocal.hasData(), isTrue);
    });

    test('signing in as a different user discards the previous data', () async {
      net.adapter.onPost(
        TestNetwork.path('auth/login'),
        (call) => fnp.MockResponse.json(sessionJson()),
      );
      await net.sessionLocal.saveUser(
        UserModel.fromJson(userJson(id: 'other')),
      );
      await net.taskLocal.saveRemote([taskModel()], fixedNow);

      await repository.login(email: 'ada@example.com', password: 'Password1');

      expect(await net.taskLocal.hasData(), isFalse);
      expect((await net.sessionLocal.readUser())?.id, 'u1');
    });

    test(
      'logout clears saved tasks, the saved user and cached responses',
      () async {
        await net.signIn();
        await net.sessionLocal.saveUser(UserModel.fromJson(userJson()));
        await net.taskLocal.saveRemote([taskModel()], fixedNow);
        net.adapter.onPost(
          TestNetwork.path('auth/logout'),
          (call) => fnp.MockResponse.bytes(Uint8List(0), statusCode: 204),
        );

        await repository.logout();

        expect(await net.taskLocal.hasData(), isFalse);
        expect(await net.sessionLocal.readUser(), isNull);
      },
    );

    test('logout clears local data even when the server call fails', () async {
      await net.signIn();
      await net.taskLocal.saveRemote([taskModel()], fixedNow);
      net.adapter.onPost(
        TestNetwork.path('auth/logout'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );

      await repository.logout();

      expect(await net.taskLocal.hasData(), isFalse);
      expect(await net.tokens.read(), isNull);
    });

    test('restoreSession works offline using the saved user', () async {
      await net.signIn();
      await net.sessionLocal.saveUser(UserModel.fromJson(userJson()));
      net.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );

      final user = await repository.restoreSession();

      expect(user?.email, 'ada@example.com');
    });

    test('restoreSession offline without a saved user fails', () async {
      await net.signIn();
      net.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a rejected session is not masked by the saved user', () async {
      await net.signIn(validFor: const Duration(minutes: -5));
      await net.sessionLocal.saveUser(UserModel.fromJson(userJson()));
      net.adapter.onPost(
        TestNetwork.path('auth/refresh'),
        (call) =>
            fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401),
      );

      expect(await repository.restoreSession(), isNull);
    });

    test('the profile is served from the saved user when offline', () async {
      await net.signIn();
      await net.sessionLocal.saveUser(UserModel.fromJson(userJson()));
      net.adapter.onGet(
        TestNetwork.path('profile'),
        (call) => fnp.MockResponse.failure(const fnp.ConnectionException()),
      );

      final profile = await ProfileRepositoryImpl(
        ProfileRemoteDataSource(net.requester),
        net.sessionLocal,
        net.logger,
      ).getProfile();

      expect(profile.isStale, isTrue);
      expect(profile.data.name, 'Ada Lovelace');
    });
  });

  test('onSessionExpired relays the notifier', () async {
    final next = repository.onSessionExpired.first;
    net.expiry.notify();
    await next.timeout(const Duration(seconds: 1));
  });
}
