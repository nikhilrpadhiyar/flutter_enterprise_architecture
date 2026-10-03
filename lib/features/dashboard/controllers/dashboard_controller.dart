import 'dart:async';

import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/usecases/get_dashboard_summary_use_case.dart';
import '../../auth/controllers/session_controller.dart';

/// Presentation state and actions of the dashboard.
class DashboardController extends GetxController {
  /// Creates the controller. [clock] is injectable for tests.
  DashboardController(
    this._getSummary,
    this._session,
    this._logger, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Update id of the welcome section.
  static const String welcomeId = 'dashboard_welcome';

  /// Update id of the summary, task lists and activity.
  static const String contentId = 'dashboard_content';

  final GetDashboardSummaryUseCase _getSummary;
  final SessionController _session;
  final AppLogger _logger;
  final DateTime Function() _clock;

  /// Current screen state.
  ViewStatus status = ViewStatus.initial;

  /// The figures, once loaded.
  DashboardSummary? summary;

  /// Whether the figures come from this device because the server could not
  /// be reached.
  bool isStale = false;

  /// Why loading failed.
  String? errorMessage;

  /// Why the last reload failed while figures were already on screen.
  String? refreshError;

  /// The current time, for overdue checks.
  DateTime get now => _clock();

  /// First name of the signed-in user, for the greeting.
  String get firstName {
    final name = _session.user?.name.trim() ?? '';
    return name.isEmpty ? '' : name.split(' ').first;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  /// Loads the figures, keeping the current ones on screen meanwhile.
  Future<void> load() async {
    status = summary == null ? ViewStatus.loading : ViewStatus.refreshing;
    errorMessage = null;
    refreshError = null;
    update(<String>[contentId]);
    try {
      final loaded = await _getSummary();
      summary = loaded.data;
      isStale = loaded.isStale;
      status = ViewStatus.success;
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'dashboard failed', error: failure);
      if (summary == null) {
        status = ViewStatus.error;
        errorMessage = failure.message;
      } else {
        status = ViewStatus.success;
        refreshError = failure.message;
      }
    }
    update(<String>[contentId, welcomeId]);
  }

  /// Reloads the figures. Used by pull to refresh.
  Future<void> reload() => load();

  /// Opens the task creation form and reloads when the user comes back.
  Future<void> openCreateTask() async {
    await Get.toNamed<void>(RouteNames.taskCreate);
    await load();
  }

  /// Opens a task and reloads when the user comes back.
  Future<void> openTask(Task task) async {
    await Get.toNamed<void>(RouteNames.taskPath(task.id));
    await load();
  }

  /// Opens the full task list.
  Future<void> openTasks() async {
    await Get.offAllNamed<void>(RouteNames.tasks);
  }

  /// Opens the project list.
  Future<void> openProjects() async {
    await Get.offAllNamed<void>(RouteNames.projects);
  }
}
