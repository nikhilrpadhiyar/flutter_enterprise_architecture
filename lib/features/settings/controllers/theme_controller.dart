import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/app_theme_mode.dart';
import '../../../domain/usecases/get_theme_mode_use_case.dart';
import '../../../domain/usecases/set_theme_mode_use_case.dart';

/// Holds the chosen colour theme for the whole app and remembers it between
/// launches.
class ThemeController extends GetxController {
  /// Creates the controller.
  ThemeController(this._getThemeMode, this._setThemeMode, this._logger);

  /// Update id of widgets that show the current choice.
  static const String themeId = 'theme_mode';

  final GetThemeModeUseCase _getThemeMode;
  final SetThemeModeUseCase _setThemeMode;
  final AppLogger _logger;

  /// The chosen theme.
  AppThemeMode mode = AppThemeMode.system;

  /// The Flutter theme mode for [mode].
  ThemeMode get themeMode => switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// Loads the saved choice. Called once at start-up.
  Future<void> load() async {
    try {
      mode = await _getThemeMode();
    } on Object catch (error) {
      _logger.warning(LogTag.controller, 'theme not loaded', error: error);
    }
    update(<String>[themeId]);
  }

  /// Applies [value] now and saves it.
  Future<void> choose(AppThemeMode value) async {
    if (value == mode) return;
    mode = value;
    update(<String>[themeId]);
    Get.changeThemeMode(themeMode);
    try {
      await _setThemeMode(value);
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'theme not saved', error: failure);
    }
  }
}
