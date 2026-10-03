import 'package:flutter_enterprise_architecture/core/logging/app_logger.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/core/routes/navigation_logger.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  test('declares every route required by the spec', () {
    expect(RouteNames.splash, '/splash');
    expect(RouteNames.login, '/login');
    expect(RouteNames.dashboard, '/dashboard');
    expect(RouteNames.projects, '/projects');
    expect(RouteNames.projectDetail, '/projects/:id');
    expect(RouteNames.tasks, '/tasks');
    expect(RouteNames.taskDetail, '/tasks/:id');
    expect(RouteNames.profile, '/profile');
  });

  test('builds concrete detail paths', () {
    expect(RouteNames.projectPath('p1'), '/projects/p1');
    expect(RouteNames.taskPath('t9'), '/tasks/t9');
  });

  test('NavigationLogger logs route changes and ignores null', () {
    final lines = <String>[];
    final logger = NavigationLogger(ConsoleAppLogger(sink: lines.add));
    logger(null);
    expect(lines, isEmpty);

    logger(Routing(current: '/tasks', previous: '/dashboard', isBack: false));
    expect(lines.single, contains('[navigation]'));
    expect(lines.single, contains('/tasks'));
    expect(lines.single, contains(LogTag.navigation));
  });
}
