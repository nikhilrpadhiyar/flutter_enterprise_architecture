/// Numeric limits used by validation and paging.
abstract final class AppLimits {
  /// Minimum accepted password length.
  static const int minPasswordLength = 8;

  /// Maximum length of a person's name.
  static const int maxNameLength = 80;

  /// Maximum length of a task title.
  static const int maxTitleLength = 120;

  /// Maximum length of a task description.
  static const int maxDescriptionLength = 2000;

  /// Number of items requested per page.
  static const int defaultPageSize = 20;

  /// Largest page size the app will request.
  static const int maxPageSize = 100;
}
