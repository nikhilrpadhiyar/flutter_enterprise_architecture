import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_limits.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/entities/assignee.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/project_query.dart';
import '../../../domain/entities/sync_state.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/requests/create_task_request.dart';
import '../../../domain/requests/update_task_request.dart';
import '../../../domain/usecases/create_task_use_case.dart';
import '../../../domain/usecases/get_assignees_use_case.dart';
import '../../../domain/usecases/get_projects_use_case.dart';
import '../../../domain/usecases/get_task_use_case.dart';
import '../../../domain/usecases/update_task_use_case.dart';

/// Presentation state and actions of the create and edit task form.
///
/// The form is in edit mode when the route carries a task id.
class TaskFormController extends GetxController {
  /// Creates the controller.
  TaskFormController(
    this._getProjects,
    this._getAssignees,
    this._getTask,
    this._createTask,
    this._updateTask,
    this._messenger,
    this._logger,
  );

  /// Update id of the whole form.
  static const String formId = 'task_form';

  final GetProjectsUseCase _getProjects;
  final GetAssigneesUseCase _getAssignees;
  final GetTaskUseCase _getTask;
  final CreateTaskUseCase _createTask;
  final UpdateTaskUseCase _updateTask;
  final AppMessenger _messenger;
  final AppLogger _logger;

  /// Text of the title field.
  final TextEditingController titleController = TextEditingController();

  /// Text of the description field.
  final TextEditingController descriptionController = TextEditingController();

  /// Id of the task being edited, or null when creating.
  String? editingId;

  /// Current state: loading the form's options, ready, empty (no project to
  /// add tasks to), error, or submitting.
  ViewStatus status = ViewStatus.initial;

  /// Why loading the form failed.
  String? errorMessage;

  /// Per-field error messages, keyed by field name.
  Map<String, String> fieldErrors = <String, String>{};

  /// Error that belongs to no single field.
  String? formError;

  /// Projects a task can belong to.
  List<Project> projects = <Project>[];

  /// People a task can be assigned to.
  List<Assignee> assignees = <Assignee>[];

  /// Chosen project id.
  String? projectId;

  /// Chosen assignee id.
  String? assigneeId;

  /// Chosen priority.
  TaskPriority priority = TaskPriority.medium;

  /// Chosen deadline.
  DateTime? dueDate;

  Task? _original;

  /// Whether an existing task is being edited.
  bool get isEditing => editingId != null;

  /// Whether the form is being saved.
  bool get isSubmitting => status == ViewStatus.submitting;

  /// Whether the form can be filled in.
  bool get isReady =>
      status == ViewStatus.success || status == ViewStatus.submitting;

  /// Whether an assignee can be removed (not possible when editing a task
  /// that already has one, because the API cannot clear it).
  bool get canUnassign => _original?.assignee == null;

  @override
  void onInit() {
    super.onInit();
    editingId = Get.parameters[RouteNames.idParam];
    projectId = Get.parameters[RouteNames.projectIdParam];
    unawaited(load());
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  /// Loads the projects, the people and, when editing, the task.
  Future<void> load() async {
    status = ViewStatus.loading;
    errorMessage = null;
    update(<String>[formId]);
    try {
      final projectsRequest = _getProjects(
        const ProjectQuery(pageSize: AppLimits.maxPageSize),
      );
      final taskRequest = editingId == null ? null : _getTask(editingId!);
      final assigneesRequest = _loadAssignees();
      projects = (await projectsRequest).data.items;
      if (taskRequest != null) _prefill((await taskRequest).data);
      assignees = await assigneesRequest;
      status = projects.isEmpty ? ViewStatus.empty : ViewStatus.success;
    } on Failure catch (failure) {
      _logger.warning(
        LogTag.controller,
        'task form load failed',
        error: failure,
      );
      status = ViewStatus.error;
      errorMessage = failure.message;
    }
    update(<String>[formId]);
  }

  /// Records the chosen project.
  void onProjectChanged(String? value) {
    projectId = value;
    _clearError('projectId');
  }

  /// Records the chosen assignee.
  void onAssigneeChanged(String? value) {
    assigneeId = value;
    _clearError('assigneeId');
  }

  /// Records the chosen priority.
  void onPriorityChanged(TaskPriority value) {
    priority = value;
    _clearError('priority');
  }

  /// Records the chosen deadline, ignoring the time of day.
  void onDueDateChanged(DateTime? value) {
    dueDate = value == null
        ? null
        : DateTime.utc(value.year, value.month, value.day);
    _clearError('dueDate');
    update(<String>[formId]);
  }

  /// Clears the error of the title field when it is edited.
  void onTitleChanged(String _) => _clearError('title');

  /// Clears the error of the description field when it is edited.
  void onDescriptionChanged(String _) => _clearError('description');

  /// Creates or updates the task and closes the form.
  Future<void> submit() async {
    if (isSubmitting || !isReady) return;
    fieldErrors = <String, String>{};
    formError = null;
    status = ViewStatus.submitting;
    update(<String>[formId]);
    try {
      final task = await _save();
      if (task != null) {
        // Leave first: a snackbar is itself a route, so showing it before
        // going back would close the snackbar instead of this page.
        Get.back<Task>(result: task);
        _messenger.show(_successMessage(task));
        return;
      }
      Get.back<void>();
      return;
    } on ValidationFailure catch (failure) {
      fieldErrors = Map<String, String>.of(failure.fieldErrors);
      formError = failure.fieldErrors.isEmpty ? failure.message : null;
    } on Failure catch (failure) {
      formError = failure.message;
    }
    status = ViewStatus.success;
    update(<String>[formId]);
  }

  /// Saves the form. Returns null when editing and nothing changed.
  Future<Task?> _save() {
    final id = editingId;
    if (id == null) {
      return _createTask(
        CreateTaskRequest(
          title: titleController.text,
          description: descriptionController.text,
          projectId: projectId ?? '',
          assigneeId: assigneeId,
          priority: priority,
          dueDate: dueDate,
        ),
      );
    }
    final request = _changes();
    if (request.isEmpty) return Future<Task?>.value();
    return _updateTask(id, request);
  }

  UpdateTaskRequest _changes() {
    final original = _original!;
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final originalDue = original.dueDate;
    final clearDue = dueDate == null && originalDue != null;
    final dueChanged = dueDate != null && dueDate != originalDue;
    return UpdateTaskRequest(
      title: title == original.title ? null : titleController.text,
      description: description == original.description
          ? null
          : descriptionController.text,
      priority: priority == original.priority ? null : priority,
      assigneeId: assigneeId == original.assignee?.id ? null : assigneeId,
      dueDate: dueChanged ? dueDate : null,
      clearDueDate: clearDue,
    );
  }

  void _prefill(Task task) {
    _original = task;
    titleController.text = task.title;
    descriptionController.text = task.description;
    projectId = task.projectId;
    assigneeId = task.assignee?.id;
    priority = task.priority;
    dueDate = task.dueDate == null
        ? null
        : DateTime.utc(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
  }

  /// People are optional: if they cannot be loaded the form still works with
  /// the task unassigned.
  Future<List<Assignee>> _loadAssignees() async {
    try {
      return (await _getAssignees()).data;
    } on Failure catch (failure) {
      _logger.warning(
        LogTag.controller,
        'assignees unavailable',
        error: failure,
      );
      return <Assignee>[];
    }
  }

  String _successMessage(Task task) {
    if (task.syncState == SyncState.pending) return AppStrings.taskSavedOffline;
    return isEditing ? AppStrings.taskUpdated : AppStrings.taskCreated;
  }

  void _clearError(String field) {
    if (fieldErrors.remove(field) != null) update(<String>[formId]);
  }
}
