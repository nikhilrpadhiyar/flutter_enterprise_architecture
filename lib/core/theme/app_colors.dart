import 'package:flutter/material.dart';

/// Brand colours and the generated colour schemes.
abstract final class AppColors {
  /// Seed colour from which both Material 3 schemes are derived.
  static const Color seed = Color(0xFF3F51B5);

  /// Light colour scheme.
  static final ColorScheme light = ColorScheme.fromSeed(seedColor: seed);

  /// Dark colour scheme.
  static final ColorScheme dark = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );
}

/// Semantic colours that Material's scheme does not provide, such as task
/// status and priority tones. Registered as a [ThemeExtension] so they adapt
/// to light and dark themes.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// Creates a set of semantic colours.
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
  });

  /// Light theme values.
  static const AppSemanticColors lightValues = AppSemanticColors(
    success: Color(0xFF2E7D32),
    warning: Color(0xFFB26A00),
    info: Color(0xFF0277BD),
    danger: Color(0xFFC62828),
  );

  /// Dark theme values.
  static const AppSemanticColors darkValues = AppSemanticColors(
    success: Color(0xFF81C784),
    warning: Color(0xFFFFB74D),
    info: Color(0xFF4FC3F7),
    danger: Color(0xFFEF9A9A),
  );

  /// Positive outcomes, completed work.
  final Color success;

  /// Attention needed, high priority.
  final Color warning;

  /// Neutral highlights, in-progress work.
  final Color info;

  /// Errors, urgent and overdue items.
  final Color danger;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? danger,
  }) => AppSemanticColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    danger: danger ?? this.danger,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
