/// Route path constants. Paths are never written as literals elsewhere.
abstract final class RouteNames {
  /// Name of the path parameter that carries an entity id.
  static const String idParam = 'id';

  /// Session restoration screen shown at launch.
  static const String splash = '/splash';

  /// Sign in screen.
  static const String login = '/login';

  /// Registration screen.
  static const String register = '/register';

  /// Dashboard home.
  static const String dashboard = '/dashboard';

  /// Project list.
  static const String projects = '/projects';

  /// Project detail pattern, used when declaring routes.
  static const String projectDetail = '/projects/:$idParam';

  /// Task list.
  static const String tasks = '/tasks';

  /// Task detail pattern, used when declaring routes.
  static const String taskDetail = '/tasks/:$idParam';

  /// Task creation form.
  static const String taskCreate = '/tasks/new';

  /// Task edit form pattern, used when declaring routes.
  static const String taskEdit = '/tasks/:$idParam/edit';

  /// Name of the query parameter that limits tasks to one project.
  static const String projectIdParam = 'projectId';

  /// Profile screen.
  static const String profile = '/profile';

  /// Concrete path for the project with [id].
  static String projectPath(String id) => '$projects/$id';

  /// Concrete path for the task with [id].
  static String taskPath(String id) => '$tasks/$id';

  /// Concrete path of the edit form for the task with [id].
  static String taskEditPath(String id) => '$tasks/$id/edit';

  /// Task list limited to the project with [projectId].
  static String tasksOfProject(String projectId) =>
      '$tasks?$projectIdParam=$projectId';
}
