import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_durations.dart';
import '../../../domain/entities/loaded.dart';
import '../../../domain/entities/paged_result.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/usecases/get_tasks_use_case.dart';
import '../../../domain/usecases/observe_pending_changes_use_case.dart';
import '../../../domain/usecases/sync_pending_changes_use_case.dart';
import '../widgets/task_filter_sheet.dart';

/// Presentation state and actions of the task list.
class TaskListController extends GetxController {
  /// Creates the controller. [clock] is injectable for tests.
  TaskListController(
    this._getTasks,
    this._observePendingChanges,
    this._syncPendingChanges,
    this._logger, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Update id of the list, its loading, empty and error states.
  static const String listId = 'task_list';

  /// Update id of the stale data and pending changes notices.
  static const String bannerId = 'task_banner';

  /// Update id of the filter summary.
  static const String filtersId = 'task_filters';

  final GetTasksUseCase _getTasks;
  final ObservePendingChangesUseCase _observePendingChanges;
  final SyncPendingChangesUseCase _syncPendingChanges;
  final AppLogger _logger;
  final DateTime Function() _clock;

  /// The search box text.
  final TextEditingController searchController = TextEditingController();

  /// Current screen state.
  ViewStatus status = ViewStatus.initial;

  /// Tasks loaded so far, across pages.
  List<Task> tasks = <Task>[];

  /// Current filters, ordering and the last loaded page.
  TaskQuery query = const TaskQuery();

  /// Number of tasks matching the query.
  int total = 0;

  /// Whether more pages can be loaded.
  bool hasMore = false;

  /// Whether the data comes from this device because the server could not be
  /// reached.
  bool isStale = false;

  /// Why the first load failed, shown when there is nothing to display.
  String? errorMessage;

  /// Why the last reload failed while data was already on screen.
  String? refreshError;

  /// Whether the next page is being fetched.
  bool isLoadingMore = false;

  /// Why the next page could not be fetched.
  String? loadMoreError;

  /// Number of changes made offline that are waiting to be sent.
  int pendingChanges = 0;

  Timer? _debounce;
  StreamSubscription<int>? _pendingSubscription;
  int _loadSerial = 0;

  /// The current time, for overdue checks.
  DateTime get now => _clock();

  /// Whether a search or filter narrows the list.
  bool get hasFilters => query.hasFilters;

  @override
  void onInit() {
    super.onInit();
    final projectId = Get.parameters[RouteNames.projectIdParam];
    if (projectId != null && projectId.isNotEmpty) {
      query = query.copyWith(projectId: projectId);
    }
    _pendingSubscription = _observePendingChanges().listen(_onPendingChanged);
    unawaited(load());
  }

  @override
  void onClose() {
    _debounce?.cancel();
    unawaited(_pendingSubscription?.cancel());
    searchController.dispose();
    super.onClose();
  }

  /// Loads the first page, keeping current items on screen while it runs.
  Future<void> load() async {
    final serial = ++_loadSerial;
    status = tasks.isEmpty ? ViewStatus.loading : ViewStatus.refreshing;
    errorMessage = null;
    refreshError = null;
    loadMoreError = null;
    update(<String>[listId]);
    try {
      final loaded = await _getTasks(query.firstPage());
      if (serial != _loadSerial) return;
      _replaceWith(loaded);
    } on Failure catch (failure) {
      if (serial != _loadSerial) return;
      _logger.warning(
        LogTag.controller,
        'task list load failed',
        error: failure,
      );
      if (tasks.isEmpty) {
        status = ViewStatus.error;
        errorMessage = failure.message;
      } else {
        status = ViewStatus.success;
        refreshError = failure.message;
      }
    }
    update(<String>[listId, bannerId]);
  }

  /// Reloads the list. Used by pull to refresh.
  Future<void> reload() => load();

  /// Loads the next page and appends it.
  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore || status != ViewStatus.success) return;
    final serial = _loadSerial;
    final next = query.nextPage();
    isLoadingMore = true;
    loadMoreError = null;
    update(<String>[listId]);
    try {
      final loaded = await _getTasks(next);
      if (serial != _loadSerial) return;
      final known = tasks.map((task) => task.id).toSet();
      tasks = <Task>[
        ...tasks,
        ...loaded.data.items.where((task) => !known.contains(task.id)),
      ];
      query = next;
      total = loaded.data.total;
      hasMore = loaded.data.hasMore;
      isStale = loaded.isStale;
    } on Failure catch (failure) {
      if (serial == _loadSerial) loadMoreError = failure.message;
    } finally {
      isLoadingMore = false;
      update(<String>[listId, bannerId]);
    }
  }

  /// Applies the search box text after the user stops typing.
  void onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () => _applySearch(text));
  }

  /// Applies a selection from the filter sheet.
  Future<void> applyFilters(TaskFilterSelection selection) {
    query = query
        .copyWith(
          statuses: selection.statuses,
          priorities: selection.priorities,
          sort: selection.sort,
        )
        .firstPage();
    update(<String>[filtersId]);
    return load();
  }

  /// Removes the search text and every filter.
  Future<void> clearFilters() {
    _debounce?.cancel();
    searchController.clear();
    query = TaskQuery(
      pageSize: query.pageSize,
      projectId: query.projectId,
      sort: query.sort,
    );
    update(<String>[filtersId]);
    return load();
  }

  /// Sends changes made offline now instead of waiting for the connection to
  /// return. The list reloads itself as changes are delivered.
  Future<void> syncNow() async {
    try {
      await _syncPendingChanges();
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'sync failed', error: failure);
      refreshError = failure.message;
      update(<String>[bannerId]);
    }
  }

  /// Opens a task and reloads the list when the user comes back.
  Future<void> openTask(Task task) async {
    await Get.toNamed<void>(RouteNames.taskPath(task.id));
    await load();
  }

  /// Opens the create form and reloads the list when the user comes back.
  Future<void> openCreate() async {
    await Get.toNamed<void>(RouteNames.taskCreate);
    await load();
  }

  Future<void> _applySearch(String text) {
    final search = text.trim();
    if (search == query.search) return Future<void>.value();
    query = query.copyWith(search: search).firstPage();
    update(<String>[filtersId]);
    return load();
  }

  void _replaceWith(Loaded<PagedResult<Task>> loaded) {
    tasks = loaded.data.items;
    total = loaded.data.total;
    hasMore = loaded.data.hasMore;
    isStale = loaded.isStale;
    query = query.copyWith(page: loaded.data.page);
    status = tasks.isEmpty ? ViewStatus.empty : ViewStatus.success;
  }

  void _onPendingChanged(int count) {
    final fewer = count < pendingChanges;
    pendingChanges = count;
    update(<String>[bannerId]);
    if (fewer) unawaited(load());
  }
}
