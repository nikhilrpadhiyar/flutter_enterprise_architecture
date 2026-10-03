import 'dart:async';

import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/logout_use_case.dart';
import '../../../domain/usecases/observe_session_expiry_use_case.dart';

/// Holds who is signed in for the whole app.
///
/// It reacts when the session expires (the networking layer could not refresh
/// the token) by clearing the user and sending the app to the sign in screen.
class SessionController extends GetxController {
  /// Creates the controller.
  SessionController(this._logout, this._observeExpiry, this._logger);

  /// Update id for widgets that show the current user.
  static const String userId = 'session_user';

  final LogoutUseCase _logout;
  final ObserveSessionExpiryUseCase _observeExpiry;
  final AppLogger _logger;

  StreamSubscription<void>? _expirySubscription;

  /// The signed-in user, or null when signed out.
  User? user;

  /// Whether the last sign out was forced by an expired session. The sign in
  /// screen shows a notice and then calls [acknowledgeExpiry].
  bool sessionExpired = false;

  /// Whether a user is signed in.
  bool get isSignedIn => user != null;

  @override
  void onInit() {
    super.onInit();
    _expirySubscription = _observeExpiry().listen((_) => _handleExpiry());
  }

  @override
  void onClose() {
    unawaited(_expirySubscription?.cancel());
    super.onClose();
  }

  /// Records [signedInUser] as the current user.
  void setUser(User signedInUser) {
    user = signedInUser;
    sessionExpired = false;
    update(<String>[userId]);
  }

  /// Clears the expiry notice after it was shown.
  void acknowledgeExpiry() => sessionExpired = false;

  /// Signs out and returns to the sign in screen.
  Future<void> signOut() async {
    _logger.info(LogTag.controller, 'sign out');
    try {
      await _logout();
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'sign out failed', error: failure);
    }
    _clearUser();
    await Get.offAllNamed<void>(RouteNames.login);
  }

  void _handleExpiry() {
    if (!isSignedIn) return;
    _logger.info(LogTag.controller, 'session expired');
    _clearUser();
    sessionExpired = true;
    unawaited(Get.offAllNamed<void>(RouteNames.login));
  }

  void _clearUser() {
    user = null;
    update(<String>[userId]);
  }
}
