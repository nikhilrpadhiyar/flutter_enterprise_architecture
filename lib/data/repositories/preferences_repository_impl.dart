import '../../domain/entities/app_theme_mode.dart';
import '../../domain/repositories/preferences_repository.dart';
import '../datasources/local/preferences_local_data_source.dart';

/// [PreferencesRepository] backed by local storage.
class PreferencesRepositoryImpl implements PreferencesRepository {
  /// Creates the repository.
  PreferencesRepositoryImpl(this._local);

  static const String _themeKey = 'theme_mode';

  final PreferencesLocalDataSource _local;

  @override
  Future<AppThemeMode> getThemeMode() async {
    final saved = await _local.read(_themeKey);
    for (final mode in AppThemeMode.values) {
      if (mode.name == saved) return mode;
    }
    return AppThemeMode.system;
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      _local.write(_themeKey, mode.name);
}
