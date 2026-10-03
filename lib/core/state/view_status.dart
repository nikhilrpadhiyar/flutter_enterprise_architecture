/// Lifecycle of the data shown by a screen.
///
/// Every major screen renders one of these states, never only the success
/// case.
enum ViewStatus {
  /// Nothing requested yet.
  initial,

  /// First load in progress.
  loading,

  /// Data loaded.
  success,

  /// Load succeeded but there is nothing to show.
  empty,

  /// Load failed.
  error,

  /// Showing existing data while reloading.
  refreshing,

  /// A user action (form submit) is in progress.
  submitting,
}
