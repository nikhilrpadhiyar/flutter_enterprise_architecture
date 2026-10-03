import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/constants/app_strings.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/navigation_logger.dart';
import 'core/routes/route_names.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/controllers/theme_controller.dart';

/// Root widget: theme, routing and navigation logging.
class MyApp extends StatelessWidget {
  /// Creates the app.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: Get.find<ThemeController>().themeMode,
      initialRoute: RouteNames.splash,
      getPages: AppRoutes.pages,
      unknownRoute: AppRoutes.unknown,
      routingCallback: Get.find<NavigationLogger>().call,
    );
  }
}
