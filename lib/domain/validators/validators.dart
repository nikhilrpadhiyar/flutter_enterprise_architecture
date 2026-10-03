import '../../core/constants/app_limits.dart';
import '../../core/constants/app_strings.dart';
import '../../core/error/failure.dart';

/// Pure input validation rules shared by use cases and forms.
///
/// Each rule returns an error message, or `null` when the value is valid.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _digit = RegExp('[0-9]');

  /// Validates an email address.
  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AppStrings.requiredField;
    return _email.hasMatch(trimmed) ? null : AppStrings.invalidEmail;
  }

  /// Validates a new password against the strength rules.
  static String? newPassword(String value) {
    if (value.isEmpty) return AppStrings.requiredField;
    final strong =
        value.length >= AppLimits.minPasswordLength &&
        _letter.hasMatch(value) &&
        _digit.hasMatch(value);
    return strong ? null : AppStrings.weakPassword;
  }

  /// Validates that a password was entered (used at sign in).
  static String? requiredPassword(String value) =>
      value.isEmpty ? AppStrings.requiredField : null;

  /// Validates a person's name.
  static String? name(String value) =>
      _requiredText(value, AppLimits.maxNameLength);

  /// Validates a task title.
  static String? taskTitle(String value) =>
      _requiredText(value, AppLimits.maxTitleLength);

  /// Validates an optional task description.
  static String? taskDescription(String? value) {
    if (value == null) return null;
    return value.length > AppLimits.maxDescriptionLength
        ? AppStrings.tooLong
        : null;
  }

  /// Validates a required, non-blank identifier.
  static String? requiredId(String value) =>
      value.trim().isEmpty ? AppStrings.requiredField : null;

  /// Throws a [ValidationFailure] listing every non-null entry of [checks].
  ///
  /// Keys are field names and values are the result of a rule above.
  static void throwIfInvalid(Map<String, String?> checks) {
    final errors = <String, String>{
      for (final entry in checks.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    if (errors.isNotEmpty) throw ValidationFailure(fieldErrors: errors);
  }

  static String? _requiredText(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AppStrings.requiredField;
    return trimmed.length > maxLength ? AppStrings.tooLong : null;
  }
}
