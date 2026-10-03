import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/projects/pages/project_detail_page.dart';
import '../../features/projects/pages/project_list_page.dart';
import '../../features/shell/pages/not_found_page.dart';
import '../../features/splash/pages/splash_page.dart';
import '../../features/tasks/pages/task_detail_page.dart';
import '../../features/tasks/pages/task_form_page.dart';
import '../../features/tasks/pages/task_list_page.dart';
import 'auth_middleware.dart';
import 'route_names.dart';

/// The route table. Pages are added here as their features are built.
///
/// Routes only name a page. Controllers are already registered by `GetDI`, so
/// no route declares a binding.
abstract final class AppRoutes {
  /// All declared pages.
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(name: RouteNames.splash, page: () => const SplashPage()),
    GetPage<dynamic>(name: RouteNames.login, page: () => const LoginPage()),
    GetPage<dynamic>(
      name: RouteNames.register,
      page: () => const RegisterPage(),
    ),
    _protected(RouteNames.dashboard, () => const DashboardPage()),
    _protected(RouteNames.projects, () => const ProjectListPage()),
    _protected(RouteNames.projectDetail, () => const ProjectDetailPage()),
    _protected(RouteNames.tasks, () => const TaskListPage()),
    // The create route must come before the detail route, or "new" would be
    // read as a task id.
    _protected(RouteNames.taskCreate, () => const TaskFormPage()),
    _protected(RouteNames.taskDetail, () => const TaskDetailPage()),
    _protected(RouteNames.taskEdit, () => const TaskFormPage()),
    _protected(RouteNames.profile, () => const ProfilePage()),
  ];

  static GetPage<dynamic> _protected(String name, Widget Function() page) {
    return GetPage<dynamic>(
      name: name,
      page: page,
      middlewares: <GetMiddleware>[AuthMiddleware()],
    );
  }

  /// Page shown for unknown routes.
  static final GetPage<dynamic> unknown = GetPage<dynamic>(
    name: '/not-found',
    page: () => const NotFoundPage(),
  );
}
