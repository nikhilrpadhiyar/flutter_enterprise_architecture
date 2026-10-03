import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/requests/register_request.dart';
import '../../../domain/usecases/register_use_case.dart';
import '../../../domain/validators/validators.dart';
import 'session_controller.dart';

/// Presentation state and actions of the registration screen.
class RegisterController extends GetxController {
  /// Creates the controller.
  RegisterController(this._register, this._session, this._logger);

  /// Update id of the whole form (fields, banner and button).
  static const String formId = 'register_form';

  final RegisterUseCase _register;
  final SessionController _session;
  final AppLogger _logger;

  /// Text of the name field.
  String name = '';

  /// Text of the email field.
  String email = '';

  /// Text of the password field.
  String password = '';

  /// Text of the confirm password field.
  String confirmPassword = '';

  /// [ViewStatus.submitting] while a registration request is running.
  ViewStatus status = ViewStatus.initial;

  /// Per-field error messages, keyed by field name.
  Map<String, String> fieldErrors = <String, String>{};

  /// Form level error that belongs to no single field.
  String? errorMessage;

  /// Whether a registration request is running.
  bool get isSubmitting => status == ViewStatus.submitting;

  /// Records an edit of the name field.
  void onNameChanged(String value) {
    name = value;
    _clearFieldError('name');
  }

  /// Records an edit of the email field.
  void onEmailChanged(String value) {
    email = value;
    _clearFieldError('email');
  }

  /// Records an edit of the password field.
  void onPasswordChanged(String value) {
    password = value;
    _clearFieldError('password');
  }

  /// Records an edit of the confirm password field.
  void onConfirmPasswordChanged(String value) {
    confirmPassword = value;
    _clearFieldError('confirmPassword');
  }

  /// Creates the account and signs in.
  ///
  /// Every field is checked before any request is sent, so the user sees all
  /// problems at once.
  Future<void> submit() async {
    if (isSubmitting) return;
    fieldErrors = _localErrors();
    errorMessage = null;
    if (fieldErrors.isNotEmpty) {
      update(<String>[formId]);
      return;
    }
    status = ViewStatus.submitting;
    update(<String>[formId]);
    try {
      final user = await _register(
        RegisterRequest(name: name, email: email, password: password),
      );
      _logger.info(LogTag.controller, 'registered');
      _session.setUser(user);
      await Get.offAllNamed<void>(RouteNames.dashboard);
      return;
    } on ValidationFailure catch (failure) {
      fieldErrors = Map<String, String>.of(failure.fieldErrors);
      errorMessage = failure.fieldErrors.isEmpty ? failure.message : null;
    } on Failure catch (failure) {
      errorMessage = failure.message;
    }
    status = ViewStatus.initial;
    update(<String>[formId]);
  }

  /// Returns to the sign in screen.
  Future<void> openSignIn() async {
    await Get.offNamed<void>(RouteNames.login);
  }

  Map<String, String> _localErrors() {
    final checks = <String, String?>{
      'name': Validators.name(name),
      'email': Validators.email(email),
      'password': Validators.newPassword(password),
      'confirmPassword': password == confirmPassword
          ? null
          : AppStrings.passwordsDoNotMatch,
    };
    return <String, String>{
      for (final entry in checks.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  void _clearFieldError(String field) {
    if (fieldErrors.remove(field) != null) update(<String>[formId]);
  }
}
