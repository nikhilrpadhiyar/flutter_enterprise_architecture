import 'package:flutter/material.dart';

/// Text styles layered on top of the Material 3 type scale.
abstract final class AppTypography {
  /// Adjusts [base] with the app's weights. Sizes stay on the Material scale
  /// so system text scaling works as expected.
  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
