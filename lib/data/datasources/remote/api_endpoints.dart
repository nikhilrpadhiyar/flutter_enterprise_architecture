/// Relative API paths. They must not start with a slash because the base URL
/// supplied to the networking client already ends with one.
abstract final class ApiEndpoints {
  /// `POST` sign in.
  static const String login = 'auth/login';

  /// `POST` registration.
  static const String register = 'auth/register';

  /// `POST` token refresh.
  static const String refresh = 'auth/refresh';

  /// `POST` sign out.
  static const String logout = 'auth/logout';

  /// `GET` and `PATCH` the current user's profile.
  static const String profile = 'profile';

  /// `GET` projects.
  static const String projects = 'projects';

  /// `GET` tasks and `POST` a new task.
  static const String tasks = 'tasks';

  /// `GET` the people tasks can be assigned to.
  static const String users = 'users';

  /// `GET` the dashboard summary.
  static const String dashboardSummary = 'dashboard/summary';

  /// Path of the project with [id].
  static String project(String id) => '$projects/$id';

  /// Path of the task with [id].
  static String task(String id) => '$tasks/$id';
}
