import '../entities/app_theme_mode.dart';
import '../repositories/preferences_repository.dart';

/// Saves the theme choice.
class SetThemeModeUseCase {
  /// Creates the use case.
  const SetThemeModeUseCase(this._repository);

  final PreferencesRepository _repository;

  /// Saves [mode].
  Future<void> call(AppThemeMode mode) => _repository.setThemeMode(mode);
}
