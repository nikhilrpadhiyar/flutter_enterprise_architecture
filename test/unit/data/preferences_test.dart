import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/preferences_local_data_source.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/task_local_data_source_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/preferences_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/entities/app_theme_mode.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/preferences_repository.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_theme_mode_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/set_theme_mode_use_case.dart';
import 'package:flutter_enterprise_architecture/features/settings/controllers/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/console_logger.dart';
import '../../helpers/test_database.dart';

class _MockPreferencesRepository extends Mock
    implements PreferencesRepository {}

void main() {
  late AppDatabase db;
  late PreferencesRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(AppThemeMode.system));

  setUp(() {
    db = createTestDatabase();
    repository = PreferencesRepositoryImpl(PreferencesLocalDataSourceImpl(db));
  });
  tearDown(() => db.close());

  group('PreferencesRepositoryImpl', () {
    test('defaults to the system theme', () async {
      expect(await repository.getThemeMode(), AppThemeMode.system);
    });

    test('remembers each choice', () async {
      for (final mode in AppThemeMode.values) {
        await repository.setThemeMode(mode);
        expect(await repository.getThemeMode(), mode);
      }
    });

    test('ignores an unknown saved value', () async {
      await PreferencesLocalDataSourceImpl(db).write('theme_mode', 'purple');
      expect(await repository.getThemeMode(), AppThemeMode.system);
    });

    test('survives clearing the user data', () async {
      await repository.setThemeMode(AppThemeMode.dark);
      await TaskLocalDataSourceImpl(db).clear();
      expect(await repository.getThemeMode(), AppThemeMode.dark);
    });
  });

  group('ThemeController', () {
    late _MockPreferencesRepository preferences;
    late ThemeController controller;
    late int updates;

    setUp(() {
      preferences = _MockPreferencesRepository();
      controller = ThemeController(
        GetThemeModeUseCase(preferences),
        SetThemeModeUseCase(preferences),
        silentLogger(),
      );
      updates = 0;
      controller.addListenerId(ThemeController.themeId, () => updates++);
    });

    test('loads the saved choice', () async {
      when(preferences.getThemeMode).thenAnswer((_) async => AppThemeMode.dark);
      await controller.load();
      expect(controller.mode, AppThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
    });

    test('falls back to the system theme if loading fails', () async {
      when(preferences.getThemeMode).thenThrow(StateError('broken'));
      await controller.load();
      expect(controller.mode, AppThemeMode.system);
      expect(controller.themeMode, ThemeMode.system);
    });

    test('maps every choice to a theme mode', () {
      final expected = <AppThemeMode, ThemeMode>{
        AppThemeMode.system: ThemeMode.system,
        AppThemeMode.light: ThemeMode.light,
        AppThemeMode.dark: ThemeMode.dark,
      };
      for (final entry in expected.entries) {
        controller.mode = entry.key;
        expect(controller.themeMode, entry.value);
      }
    });

    test('choosing the current theme does nothing', () async {
      await controller.choose(AppThemeMode.system);
      verifyNever(() => preferences.setThemeMode(any()));
      expect(updates, 0);
    });

    test('a failure to save keeps the choice for this session', () async {
      when(() => preferences.setThemeMode(any()))
          .thenThrow(const CacheFailure());

      await controller.choose(AppThemeMode.light);

      expect(controller.mode, AppThemeMode.light);
      expect(updates, 1);
    });
  });
}
