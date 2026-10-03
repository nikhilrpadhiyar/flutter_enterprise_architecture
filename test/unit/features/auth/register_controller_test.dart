import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/domain/requests/register_request.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/register_controller.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_use_cases.dart';

void main() {
  late MockRegisterUseCase register;
  late RegisterController controller;
  late int rebuilds;

  setUpAll(
    () => registerFallbackValue(
      const RegisterRequest(name: 'n', email: 'e', password: 'p'),
    ),
  );

  setUp(() {
    register = MockRegisterUseCase();
    final observe = MockObserveSessionExpiryUseCase();
    when(observe.call).thenAnswer((_) => const Stream<void>.empty());
    final logger = ConsoleAppLogger(sink: (_) {});
    controller = RegisterController(
      register,
      SessionController(MockLogoutUseCase(), observe, logger),
      logger,
    );
    rebuilds = 0;
    controller.addListenerId(RegisterController.formId, () => rebuilds++);
  });

  void fillValid() => controller
    ..onNameChanged('Ada')
    ..onEmailChanged('ada@example.com')
    ..onPasswordChanged('Secret123')
    ..onConfirmPasswordChanged('Secret123');

  test(
    'blank fields are reported together without calling the server',
    () async {
      await controller.submit();

      expect(
        controller.fieldErrors.keys,
        containsAll(<String>['name', 'email', 'password']),
      );
      expect(controller.isSubmitting, isFalse);
      verifyNever(() => register(any()));
      expect(rebuilds, 1);
    },
  );

  test(
    'mismatching passwords are reported on the confirmation field',
    () async {
      fillValid();
      controller.onConfirmPasswordChanged('Different1');

      await controller.submit();

      expect(controller.fieldErrors, <String, String>{
        'confirmPassword': AppStrings.passwordsDoNotMatch,
      });
      verifyNever(() => register(any()));
    },
  );

  test('a weak password is rejected locally', () async {
    fillValid();
    controller
      ..onPasswordChanged('short')
      ..onConfirmPasswordChanged('short');

    await controller.submit();

    expect(controller.fieldErrors['password'], AppStrings.weakPassword);
  });

  test('editing a field clears only its own error', () async {
    await controller.submit();
    final before = rebuilds;

    controller.onNameChanged('Ada');

    expect(controller.fieldErrors.containsKey('name'), isFalse);
    expect(controller.fieldErrors.containsKey('email'), isTrue);
    expect(rebuilds, before + 1);
  });

  test('server field errors are shown on their fields', () async {
    fillValid();
    when(() => register(any())).thenThrow(
      const ValidationFailure(
        fieldErrors: <String, String>{'email': 'Email is already registered'},
      ),
    );

    await controller.submit();

    expect(controller.fieldErrors['email'], 'Email is already registered');
    expect(controller.isSubmitting, isFalse);
  });

  test('other failures become a form message', () async {
    fillValid();
    when(() => register(any())).thenThrow(const NetworkFailure());

    await controller.submit();

    expect(controller.errorMessage, AppStrings.failureNetwork);
    expect(controller.fieldErrors, isEmpty);
    verify(
      () => register(
        const RegisterRequest(
          name: 'Ada',
          email: 'ada@example.com',
          password: 'Secret123',
        ),
      ),
    ).called(1);
  });
}
