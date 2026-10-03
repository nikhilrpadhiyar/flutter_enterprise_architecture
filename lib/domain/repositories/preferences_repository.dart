import '../entities/app_theme_mode.dart';

/// Settings that belong to the device rather than the signed-in user.
abstract interface class PreferencesRepository {
  /// The saved theme choice, or [AppThemeMode.system] when none was saved.
  Future<AppThemeMode> getThemeMode();

  /// Saves the theme choice.
  Future<void> setThemeMode(AppThemeMode mode);
}
