import 'dart:async';

import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/entities/sync_state.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_status.dart';
import '../../../domain/requests/update_task_request.dart';
import '../../../domain/usecases/delete_task_use_case.dart';
import '../../../domain/usecases/discard_local_changes_use_case.dart';
import '../../../domain/usecases/get_task_use_case.dart';
import '../../../domain/usecases/update_task_use_case.dart';

/// Presentation state and actions of the task detail screen.
class TaskDetailController extends GetxController {
  /// Creates the controller.
  TaskDetailController(
    this._getTask,
    this._updateTask,
    this._deleteTask,
    this._discardChanges,
    this._messenger,
    this._logger,
  );

  /// Update id of the task content.
  static const String detailId = 'task_detail';

  /// Update id of the action buttons and their progress.
  static const String actionsId = 'task_actions';

  final GetTaskUseCase _getTask;
  final UpdateTaskUseCase _updateTask;
  final DeleteTaskUseCase _deleteTask;
  final DiscardLocalChangesUseCase _discardChanges;
  final AppMessenger _messenger;
  final AppLogger _logger;

  /// Id of the task being shown, from the route.
  late final String taskId;

  /// Current screen state.
  ViewStatus status = ViewStatus.initial;

  /// The task, once loaded.
  Task? task;

  /// Whether the task comes from this device because the server could not be
  /// reached.
  bool isStale = false;

  /// Why loading failed.
  String? errorMessage;

  /// Why the last action failed.
  String? actionError;

  /// Whether an update, deletion or discard is running.
  bool get isBusy => status == ViewStatus.submitting;

  /// Whether the server rejected a change to this task.
  bool get hasRejectedChange => task?.syncState == SyncState.failed;

  /// Whether the task can be edited or deleted (tasks that exist only on this
  /// device cannot until they sync).
  bool get canModify =>
      task != null && !task!.id.startsWith(_localIdPrefix) && !isBusy;

  static const String _localIdPrefix = 'local-';

  @override
  void onInit() {
    super.onInit();
    taskId = Get.parameters[RouteNames.idParam] ?? '';
    unawaited(load());
  }

  /// Loads the task.
  Future<void> load() async {
    status = task == null ? ViewStatus.loading : ViewStatus.refreshing;
    errorMessage = null;
    update(<String>[detailId]);
    try {
      final loaded = await _getTask(taskId);
      task = loaded.data;
      isStale = loaded.isStale;
      status = ViewStatus.success;
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'task load failed', error: failure);
      status = ViewStatus.error;
      errorMessage = failure.message;
    }
    update(<String>[detailId, actionsId]);
  }

  /// Changes the task's status.
  Future<void> changeStatus(TaskStatus value) {
    if (task?.status == value) return Future<void>.value();
    return _apply(UpdateTaskRequest(status: value));
  }

  /// Changes the task's priority.
  Future<void> changePriority(TaskPriority value) {
    if (task?.priority == value) return Future<void>.value();
    return _apply(UpdateTaskRequest(priority: value));
  }

  /// Deletes the task and returns to the list.
  Future<void> delete() async {
    if (!canModify) return;
    _begin();
    try {
      await _deleteTask(taskId);
      // Leave first: a snackbar is itself a route, so showing it before
      // going back would close the snackbar instead of this page.
      Get.back<void>();
      _messenger.show(AppStrings.taskDeleted);
      return;
    } on Failure catch (failure) {
      actionError = failure.message;
    }
    _finish();
  }

  /// Throws away the rejected local change and shows the latest version.
  Future<void> discardChanges() async {
    if (isBusy) return;
    _begin();
    try {
      await _discardChanges(taskId);
    } on Failure catch (failure) {
      actionError = failure.message;
      _finish();
      return;
    }
    if (taskId.startsWith(_localIdPrefix)) {
      Get.back<void>();
      return;
    }
    task = null;
    await load();
  }

  /// Opens the edit form and reloads when the user comes back.
  Future<void> openEdit() async {
    if (!canModify) return;
    await Get.toNamed<void>(RouteNames.taskEditPath(taskId));
    await load();
  }

  Future<void> _apply(UpdateTaskRequest request) async {
    if (!canModify) return;
    _begin();
    try {
      task = await _updateTask(taskId, request);
      status = ViewStatus.success;
    } on Failure catch (failure) {
      actionError = failure.message;
    }
    _finish();
  }

  void _begin() {
    status = ViewStatus.submitting;
    actionError = null;
    update(<String>[actionsId]);
  }

  void _finish() {
    if (status == ViewStatus.submitting) status = ViewStatus.success;
    update(<String>[detailId, actionsId]);
  }
}
