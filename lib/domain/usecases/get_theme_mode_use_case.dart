import '../entities/app_theme_mode.dart';
import '../repositories/preferences_repository.dart';

/// Reads the saved theme choice.
class GetThemeModeUseCase {
  /// Creates the use case.
  const GetThemeModeUseCase(this._repository);

  final PreferencesRepository _repository;

  /// Returns the saved choice, or the system theme by default.
  Future<AppThemeMode> call() => _repository.getThemeMode();
}
