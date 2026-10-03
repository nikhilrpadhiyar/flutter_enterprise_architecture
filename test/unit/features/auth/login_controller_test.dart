import 'dart:async';

import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/core/state/view_status.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/login_controller.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_use_cases.dart';

void main() {
  late MockLoginUseCase login;
  late SessionController session;
  late LoginController controller;
  late int rebuilds;

  setUp(() {
    login = MockLoginUseCase();
    final observe = MockObserveSessionExpiryUseCase();
    when(observe.call).thenAnswer((_) => const Stream<void>.empty());
    final logger = ConsoleAppLogger(sink: (_) {});
    session = SessionController(MockLogoutUseCase(), observe, logger);
    controller = LoginController(login, session, logger);
    rebuilds = 0;
    controller.addListenerId(LoginController.formId, () => rebuilds++);
  });

  void stubLoginThrows(Failure failure) => when(
    () => login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenThrow(failure);

  test('starts idle with no errors', () {
    controller.onInit();
    expect(controller.status, ViewStatus.initial);
    expect(controller.isSubmitting, isFalse);
    expect(controller.fieldErrors, isEmpty);
    expect(controller.errorMessage, isNull);
    expect(controller.showSessionExpiredNotice, isFalse);
  });

  test('field edits are stored without rebuilding', () {
    controller
      ..onEmailChanged('ada@example.com')
      ..onPasswordChanged('secret');
    expect(controller.email, 'ada@example.com');
    expect(controller.password, 'secret');
    expect(rebuilds, 0);
  });

  test(
    'field errors show per field and clear when that field is edited',
    () async {
      stubLoginThrows(
        const ValidationFailure(
          fieldErrors: <String, String>{
            'email': 'Enter a valid email address.',
            'password': 'This field is required.',
          },
        ),
      );

      await controller.submit();
      expect(
        controller.fieldErrors.keys,
        containsAll(<String>['email', 'password']),
      );
      expect(controller.errorMessage, isNull);
      expect(controller.status, ViewStatus.initial);
      final afterSubmit = rebuilds;

      controller.onEmailChanged('a@b.co');
      expect(controller.fieldErrors.keys, <String>['password']);
      expect(rebuilds, afterSubmit + 1);

      controller.onEmailChanged('a@b.com');
      expect(rebuilds, afterSubmit + 1);
    },
  );

  test('a validation failure without fields becomes a form message', () async {
    stubLoginThrows(const ValidationFailure());
    await controller.submit();
    expect(controller.errorMessage, AppStrings.failureValidation);
  });

  test('other failures become a form message and re-enable the form', () async {
    stubLoginThrows(const AuthenticationFailure());
    await controller.submit();
    expect(controller.errorMessage, AppStrings.failureAuthentication);
    expect(controller.isSubmitting, isFalse);
    expect(controller.fieldErrors, isEmpty);
  });

  test('submitting passes the entered credentials', () async {
    controller
      ..onEmailChanged('ada@example.com')
      ..onPasswordChanged('secret');
    stubLoginThrows(const NetworkFailure());

    await controller.submit();

    verify(() => login(email: 'ada@example.com', password: 'secret')).called(1);
  });

  test('a second submit while one is running is ignored', () async {
    final completer = Completer<void>();
    when(
      () => login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      await completer.future;
      throw const NetworkFailure();
    });

    final first = controller.submit();
    expect(controller.isSubmitting, isTrue);
    await controller.submit();
    completer.complete();
    await first;

    verify(
      () => login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
    expect(controller.isSubmitting, isFalse);
  });

  test('each submit clears the previous error before retrying', () async {
    stubLoginThrows(const NetworkFailure());
    await controller.submit();
    expect(controller.errorMessage, AppStrings.failureNetwork);

    final completer = Completer<void>();
    when(
      () => login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      await completer.future;
      throw const TimeoutFailure();
    });
    final retry = controller.submit();
    expect(controller.errorMessage, isNull);
    expect(controller.isSubmitting, isTrue);

    completer.complete();
    await retry;
    expect(controller.errorMessage, AppStrings.failureTimeout);
  });

  test('shows the session expired notice once', () {
    session.sessionExpired = true;
    controller.onInit();
    expect(controller.showSessionExpiredNotice, isTrue);
    expect(session.sessionExpired, isFalse);
  });
}
