import 'package:flutter_enterprise_architecture/core/constants/app_limits.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/domain/validators/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('accepts well formed addresses', () {
      expect(Validators.email('ada@example.com'), isNull);
      expect(Validators.email('  ada@example.com '), isNull);
    });

    test('rejects empty and malformed addresses', () {
      expect(Validators.email(''), AppStrings.requiredField);
      expect(Validators.email('   '), AppStrings.requiredField);
      expect(Validators.email('ada'), AppStrings.invalidEmail);
      expect(Validators.email('ada@'), AppStrings.invalidEmail);
      expect(Validators.email('ada@example'), AppStrings.invalidEmail);
    });
  });

  group('newPassword', () {
    test('requires length, a letter and a digit', () {
      expect(Validators.newPassword('abcdefg1'), isNull);
      expect(Validators.newPassword('short1'), AppStrings.weakPassword);
      expect(Validators.newPassword('allletters'), AppStrings.weakPassword);
      expect(Validators.newPassword('12345678'), AppStrings.weakPassword);
      expect(Validators.newPassword(''), AppStrings.requiredField);
    });
  });

  group('text rules', () {
    test('name and title are required and length limited', () {
      expect(Validators.name('Ada'), isNull);
      expect(Validators.name('  '), AppStrings.requiredField);
      expect(
        Validators.name('a' * (AppLimits.maxNameLength + 1)),
        AppStrings.tooLong,
      );
      expect(Validators.taskTitle('a' * AppLimits.maxTitleLength), isNull);
      expect(
        Validators.taskTitle('a' * (AppLimits.maxTitleLength + 1)),
        AppStrings.tooLong,
      );
    });

    test('description is optional but length limited', () {
      expect(Validators.taskDescription(null), isNull);
      expect(Validators.taskDescription(''), isNull);
      expect(
        Validators.taskDescription('a' * (AppLimits.maxDescriptionLength + 1)),
        AppStrings.tooLong,
      );
    });

    test('requiredId rejects blank ids', () {
      expect(Validators.requiredId('p1'), isNull);
      expect(Validators.requiredId(' '), AppStrings.requiredField);
    });
  });

  group('throwIfInvalid', () {
    test('does nothing when every check passes', () {
      expect(
        () => Validators.throwIfInvalid(<String, String?>{'a': null}),
        returnsNormally,
      );
    });

    test('throws a ValidationFailure listing only failing fields', () {
      try {
        Validators.throwIfInvalid(<String, String?>{'a': null, 'b': 'bad'});
        fail('expected a ValidationFailure');
      } on ValidationFailure catch (failure) {
        expect(failure.fieldErrors, <String, String>{'b': 'bad'});
      }
    });
  });
}
