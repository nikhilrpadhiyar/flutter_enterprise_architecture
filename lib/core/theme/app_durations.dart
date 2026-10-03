/// Animation and debounce durations.
abstract final class AppDurations {
  /// Delay before a search query is sent after the last keystroke.
  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// How long a snackbar stays visible.
  static const Duration snackbar = Duration(seconds: 4);
}
