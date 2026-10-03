import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Common logical screen sizes used by adaptive layout tests.
abstract final class TestScreens {
  static const Size phone = Size(390, 844);
  static const Size tablet = Size(800, 1000);
  static const Size desktop = Size(1400, 900);
}

/// Pumps [child] inside a themed Material app at the given [size].
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = TestScreens.phone,
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );
}
