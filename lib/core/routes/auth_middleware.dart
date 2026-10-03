import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../features/auth/controllers/session_controller.dart';
import 'route_names.dart';

/// Sends signed-out users to the sign in screen.
///
/// Attach it to every route that needs a session. It reads the
/// already-registered [SessionController]; it is a route guard, not a Binding.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final isSignedIn = Get.find<SessionController>().isSignedIn;
    return isSignedIn ? null : const RouteSettings(name: RouteNames.login);
  }
}
