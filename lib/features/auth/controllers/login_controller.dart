import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/usecases/login_use_case.dart';
import 'session_controller.dart';

/// Presentation state and actions of the sign in screen.
class LoginController extends GetxController {
  /// Creates the controller.
  LoginController(this._login, this._session, this._logger);

  /// Update id of the whole form (fields, banner and button).
  static const String formId = 'login_form';

  final LoginUseCase _login;
  final SessionController _session;
  final AppLogger _logger;

  /// Text of the email field.
  String email = '';

  /// Text of the password field.
  String password = '';

  /// [ViewStatus.submitting] while a sign in request is running.
  ViewStatus status = ViewStatus.initial;

  /// Per-field error messages, keyed by field name.
  Map<String, String> fieldErrors = <String, String>{};

  /// Form level error that belongs to no single field.
  String? errorMessage;

  /// Whether to tell the user their session expired.
  late final bool showSessionExpiredNotice;

  /// Whether a sign in request is running.
  bool get isSubmitting => status == ViewStatus.submitting;

  @override
  void onInit() {
    super.onInit();
    showSessionExpiredNotice = _session.sessionExpired;
    _session.acknowledgeExpiry();
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

  /// Signs in with the entered credentials.
  Future<void> submit() async {
    if (isSubmitting) return;
    status = ViewStatus.submitting;
    fieldErrors = <String, String>{};
    errorMessage = null;
    update(<String>[formId]);
    try {
      final user = await _login(email: email, password: password);
      _logger.info(LogTag.controller, 'signed in');
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

  /// Opens the registration screen.
  Future<void> openRegister() async {
    await Get.toNamed<void>(RouteNames.register);
  }

  void _clearFieldError(String field) {
    if (fieldErrors.remove(field) != null) update(<String>[formId]);
  }
}
