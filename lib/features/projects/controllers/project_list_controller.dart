import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_durations.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/project_query.dart';
import '../../../domain/usecases/get_projects_use_case.dart';

/// Presentation state and actions of the project list.
class ProjectListController extends GetxController {
  /// Creates the controller.
  ProjectListController(this._getProjects, this._logger);

  /// Update id of the list and its loading, empty and error states.
  static const String listId = 'project_list';

  /// Update id of the stale data notice.
  static const String bannerId = 'project_banner';

  final GetProjectsUseCase _getProjects;
  final AppLogger _logger;

  /// The search box text.
  final TextEditingController searchController = TextEditingController();

  /// Current screen state.
  ViewStatus status = ViewStatus.initial;

  /// Projects loaded so far, across pages.
  List<Project> projects = <Project>[];

  /// Current search and the last loaded page.
  ProjectQuery query = const ProjectQuery();

  /// Whether more pages can be loaded.
  bool hasMore = false;

  /// Whether the data comes from this device because the server could not be
  /// reached.
  bool isStale = false;

  /// Why the first load failed.
  String? errorMessage;

  /// Why the last reload failed while data was already on screen.
  String? refreshError;

  /// Whether the next page is being fetched.
  bool isLoadingMore = false;

  Timer? _debounce;
  int _loadSerial = 0;

  /// Whether a search narrows the list.
  bool get hasSearch => query.search.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  /// Loads the first page, keeping current items on screen while it runs.
  Future<void> load() async {
    final serial = ++_loadSerial;
    status = projects.isEmpty ? ViewStatus.loading : ViewStatus.refreshing;
    errorMessage = null;
    refreshError = null;
    update(<String>[listId]);
    try {
      final loaded = await _getProjects(query.copyWith(page: 1));
      if (serial != _loadSerial) return;
      projects = loaded.data.items;
      hasMore = loaded.data.hasMore;
      isStale = loaded.isStale;
      query = query.copyWith(page: loaded.data.page);
      status = projects.isEmpty ? ViewStatus.empty : ViewStatus.success;
    } on Failure catch (failure) {
      if (serial != _loadSerial) return;
      _logger.warning(LogTag.controller, 'project list failed', error: failure);
      if (projects.isEmpty) {
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
    final next = query.copyWith(page: query.page + 1);
    isLoadingMore = true;
    update(<String>[listId]);
    try {
      final loaded = await _getProjects(next);
      if (serial != _loadSerial) return;
      final known = projects.map((project) => project.id).toSet();
      projects = <Project>[
        ...projects,
        ...loaded.data.items.where((project) => !known.contains(project.id)),
      ];
      query = next;
      hasMore = loaded.data.hasMore;
    } on Failure catch (failure) {
      if (serial == _loadSerial) refreshError = failure.message;
    } finally {
      isLoadingMore = false;
      update(<String>[listId, bannerId]);
    }
  }

  /// Applies the search box text after the user stops typing.
  void onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () {
      final search = text.trim();
      if (search == query.search) return;
      query = query.copyWith(search: search, page: 1);
      unawaited(load());
    });
  }

  /// Removes the search text.
  Future<void> clearSearch() {
    _debounce?.cancel();
    searchController.clear();
    query = query.copyWith(search: '', page: 1);
    return load();
  }

  /// Opens a project.
  Future<void> openProject(Project project) async {
    await Get.toNamed<void>(RouteNames.projectPath(project.id));
  }
}
