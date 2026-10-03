import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_durations.dart';

/// Shows brief messages to the user, such as "Task deleted".
///
/// Controllers depend on this interface instead of calling UI code directly,
/// which keeps them testable.
abstract interface class AppMessenger {
  /// Shows [message] for a few seconds.
  void show(String message);
}

/// [AppMessenger] that shows a Material snackbar on the current screen.
///
/// A real `SnackBar` is laid out by the screen's `Scaffold`, so it sits above
/// the bottom navigation bar instead of covering it and blocking taps.
class SnackbarMessenger implements AppMessenger {
  /// Creates the messenger.
  const SnackbarMessenger();

  @override
  void show(String message) {
    final context = Get.context;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: AppDurations.snackbar,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
