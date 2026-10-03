import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_strings.dart';
import '../widgets/app_shell_scaffold.dart';
import 'route_names.dart';

/// The top-level destinations of the app shell, in navigation order.
abstract final class AppDestinations {
  /// All destinations.
  static const List<AppDestination> all = <AppDestination>[
    AppDestination(
      label: AppStrings.navDashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      route: RouteNames.dashboard,
    ),
    AppDestination(
      label: AppStrings.navProjects,
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      route: RouteNames.projects,
    ),
    AppDestination(
      label: AppStrings.navTasks,
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      route: RouteNames.tasks,
    ),
    AppDestination(
      label: AppStrings.navProfile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      route: RouteNames.profile,
    ),
  ];

  /// Index of the destination that opens [route].
  static int indexOf(String route) =>
      all.indexWhere((destination) => destination.route == route);

  /// Opens the destination at [index], replacing the current stack.
  static void open(int index) {
    final route = all[index].route;
    if (Get.currentRoute == route) return;
    Get.offAllNamed<void>(route);
  }
}
