import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/domain/requests/register_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/login_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/logout_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_session_expiry_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/register_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/restore_session_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockAuthRepository repository;

  setUpAll(
    () => registerFallbackValue(
      const RegisterRequest(name: 'n', email: 'e', password: 'p'),
    ),
  );

  setUp(() => repository = MockAuthRepository());

  group('LoginUseCase', () {
    test('rejects bad input without calling the repository', () async {
      final useCase = LoginUseCase(repository);
      await expectLater(
        useCase(email: 'nope', password: ''),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors.keys,
            'fields',
            containsAll(<String>['email', 'password']),
          ),
        ),
      );
      verifyNever(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('trims the email and returns the user', () async {
      final user = buildUser();
      when(() => repository.login(email: 'ada@example.com', password: 'pw'))
          .thenAnswer((_) async => user);

      final result = await LoginUseCase(repository)(
        email: '  ada@example.com ',
        password: 'pw',
      );

      expect(result, user);
    });

    test('propagates repository failures', () async {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthenticationFailure());

      await expectLater(
        LoginUseCase(repository)(email: 'a@b.co', password: 'pw'),
        throwsA(isA<AuthenticationFailure>()),
      );
    });
  });

  group('RegisterUseCase', () {
    test('rejects weak passwords and blank names', () async {
      await expectLater(
        RegisterUseCase(repository)(
          const RegisterRequest(name: ' ', email: 'a@b.co', password: 'weak'),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors.keys,
            'fields',
            containsAll(<String>['name', 'password']),
          ),
        ),
      );
      verifyNever(() => repository.register(any()));
    });

    test('sends trimmed values to the repository', () async {
      final user = buildUser();
      when(() => repository.register(any())).thenAnswer((_) async => user);

      final result = await RegisterUseCase(repository)(
        const RegisterRequest(
          name: ' Ada ',
          email: ' ada@example.com ',
          password: 'password1',
        ),
      );

      expect(result, user);
      verify(
        () => repository.register(
          const RegisterRequest(
            name: 'Ada',
            email: 'ada@example.com',
            password: 'password1',
          ),
        ),
      ).called(1);
    });
  });

  test('LogoutUseCase signs out', () async {
    when(() => repository.logout()).thenAnswer((_) async {});
    await LogoutUseCase(repository)();
    verify(() => repository.logout()).called(1);
  });

  group('RestoreSessionUseCase', () {
    test('returns the saved user', () async {
      final user = buildUser();
      when(() => repository.restoreSession()).thenAnswer((_) async => user);
      expect(await RestoreSessionUseCase(repository)(), user);
    });

    test('returns null when signed out', () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => null);
      expect(await RestoreSessionUseCase(repository)(), isNull);
    });
  });

  test('ObserveSessionExpiryUseCase exposes the repository stream', () async {
    when(() => repository.onSessionExpired)
        .thenAnswer((_) => Stream<void>.fromIterable(<void>[null]));
    expect(await ObserveSessionExpiryUseCase(repository)().length, 1);
  });
}
