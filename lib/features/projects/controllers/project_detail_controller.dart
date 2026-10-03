import 'dart:async';

import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/usecases/get_project_use_case.dart';
import '../../../domain/usecases/get_tasks_use_case.dart';

/// Presentation state and actions of the project detail screen.
class ProjectDetailController extends GetxController {
  /// Creates the controller. [clock] is injectable for tests.
  ProjectDetailController(
    this._getProject,
    this._getTasks,
    this._logger, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Update id of the whole screen.
  static const String detailId = 'project_detail';

  /// Number of tasks previewed on the screen.
  static const int previewSize = 5;

  final GetProjectUseCase _getProject;
  final GetTasksUseCase _getTasks;
  final AppLogger _logger;
  final DateTime Function() _clock;

  /// Id of the project, from the route.
  late final String projectId;

  /// Current screen state.
  ViewStatus status = ViewStatus.initial;

  /// The project, once loaded.
  Project? project;

  /// A few of the project's tasks.
  List<Task> tasks = <Task>[];

  /// Total number of tasks in the project.
  int taskTotal = 0;

  /// Whether the data comes from this device because the server could not be
  /// reached.
  bool isStale = false;

  /// Why the project could not be loaded.
  String? errorMessage;

  /// Why the task preview could not be loaded.
  String? tasksError;

  /// The current time, for overdue checks.
  DateTime get now => _clock();

  @override
  void onInit() {
    super.onInit();
    projectId = Get.parameters[RouteNames.idParam] ?? '';
    unawaited(load());
  }

  /// Loads the project and a preview of its tasks.
  Future<void> load() async {
    status = project == null ? ViewStatus.loading : ViewStatus.refreshing;
    errorMessage = null;
    tasksError = null;
    update(<String>[detailId]);
    final tasksRequest = _loadTasks();
    try {
      final loaded = await _getProject(projectId);
      project = loaded.data;
      isStale = loaded.isStale;
      status = ViewStatus.success;
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'project load failed', error: failure);
      status = ViewStatus.error;
      errorMessage = failure.message;
    }
    await tasksRequest;
    update(<String>[detailId]);
  }

  /// Opens one of the project's tasks.
  Future<void> openTask(Task task) async {
    await Get.toNamed<void>(RouteNames.taskPath(task.id));
    await load();
  }

  /// Opens the full task list limited to this project.
  Future<void> openAllTasks() async {
    await Get.toNamed<void>(RouteNames.tasksOfProject(projectId));
  }

  Future<void> _loadTasks() async {
    try {
      final loaded = await _getTasks(
        TaskQuery(pageSize: previewSize, projectId: projectId),
      );
      tasks = loaded.data.items;
      taskTotal = loaded.data.total;
    } on Failure catch (failure) {
      tasksError = failure.message;
    }
  }
}
