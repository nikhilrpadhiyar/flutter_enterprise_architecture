import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_colors.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_sizes.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes use Material 3 with matching brightness', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('both themes expose semantic colours', () {
    expect(
      AppTheme.light.extension<AppSemanticColors>(),
      AppSemanticColors.lightValues,
    );
    expect(
      AppTheme.dark.extension<AppSemanticColors>(),
      AppSemanticColors.darkValues,
    );
  });

  test('buttons keep the minimum touch target', () {
    final size = AppTheme.light.filledButtonTheme.style?.minimumSize?.resolve(
      <WidgetState>{},
    );
    expect(size?.height, AppSizes.minTouchTarget);
  });

  test('semantic colours interpolate', () {
    final mid = AppSemanticColors.lightValues.lerp(
      AppSemanticColors.darkValues,
      0.5,
    );
    expect(mid.success, isNot(AppSemanticColors.lightValues.success));
  });
}
