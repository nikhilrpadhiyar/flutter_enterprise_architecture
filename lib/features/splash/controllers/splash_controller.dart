import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/usecases/restore_session_use_case.dart';
import '../../auth/controllers/session_controller.dart';

/// Restores a saved session at launch and routes accordingly.
class SplashController extends GetxController {
  /// Creates the controller.
  SplashController(this._restoreSession, this._session, this._logger);

  /// Update id of the splash content.
  static const String stateId = 'splash_state';

  final RestoreSessionUseCase _restoreSession;
  final SessionController _session;
  final AppLogger _logger;

  /// Current state: loading while restoring, error when it failed.
  ViewStatus status = ViewStatus.initial;

  /// User-friendly reason restoration failed.
  String? errorMessage;

  @override
  void onReady() {
    super.onReady();
    start();
  }

  /// Restores the session and opens the dashboard or the sign in screen.
  ///
  /// Also used as the retry action after a failure.
  Future<void> start() async {
    status = ViewStatus.loading;
    errorMessage = null;
    update(<String>[stateId]);
    try {
      final user = await _restoreSession();
      if (user != null) _session.setUser(user);
      status = ViewStatus.success;
      await Get.offAllNamed<void>(
        user == null ? RouteNames.login : RouteNames.dashboard,
      );
    } on Failure catch (failure) {
      _logger.warning(
        LogTag.controller,
        'session restore failed',
        error: failure,
      );
      status = ViewStatus.error;
      errorMessage = failure.message;
      update(<String>[stateId]);
    }
  }
}
