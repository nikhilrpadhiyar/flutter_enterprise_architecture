import 'package:get/get.dart';

import '../logging/app_logger.dart';

/// Logs route changes. Pass [call] as `GetMaterialApp.routingCallback`.
class NavigationLogger {
  /// Creates a navigation logger writing to [_logger].
  const NavigationLogger(this._logger);

  final AppLogger _logger;

  /// Handles a routing event from GetX.
  void call(Routing? routing) {
    if (routing == null) return;
    _logger.info(
      LogTag.navigation,
      'route changed',
      context: <String, Object?>{
        'current': routing.current,
        'previous': routing.previous,
        'isBack': routing.isBack ?? false,
      },
    );
  }
}
