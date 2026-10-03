import 'package:flutter_enterprise_architecture/core/config/app_config.dart';
import 'package:flutter_enterprise_architecture/core/logging/app_logger.dart';
import 'package:flutter_enterprise_architecture/data/repositories/auth_repository_impl.dart';
import 'package:flutter_enterprise_architecture/data/repositories/task_repository_impl.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/auth_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/dashboard_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/profile_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/project_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/sync_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/task_repository.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/create_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/delete_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/discard_local_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_assignees_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_dashboard_summary_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_profile_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_project_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_projects_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_tasks_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/get_theme_mode_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/login_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/logout_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_pending_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_session_expiry_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/register_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/restore_session_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/set_theme_mode_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/sync_pending_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/update_profile_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/update_task_use_case.dart';
import 'package:flutter_enterprise_architecture/features/auth/controllers/session_controller.dart';
import 'package:flutter_enterprise_architecture/features/dashboard/controllers/dashboard_controller.dart';
import 'package:flutter_enterprise_architecture/features/profile/controllers/profile_controller.dart';
import 'package:flutter_enterprise_architecture/features/projects/controllers/project_detail_controller.dart';
import 'package:flutter_enterprise_architecture/features/projects/controllers/project_list_controller.dart';
import 'package:flutter_enterprise_architecture/features/settings/controllers/theme_controller.dart';
import 'package:flutter_enterprise_architecture/features/splash/controllers/splash_controller.dart';
import 'package:flutter_enterprise_architecture/features/tasks/controllers/task_detail_controller.dart';
import 'package:flutter_enterprise_architecture/features/tasks/controllers/task_form_controller.dart';
import 'package:flutter_enterprise_architecture/features/tasks/controllers/task_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/test_di.dart';

void main() {
  late TestDi di;

  setUp(() async => di = await TestDi.create());
  tearDown(() => di.dispose());

  test('registers infrastructure', () {
    expect(Get.isRegistered<AppConfig>(), isTrue);
    expect(Get.isRegistered<AppLogger>(), isTrue);
  });

  test('registers every repository interface with its implementation', () {
    expect(Get.find<AuthRepository>(), isA<AuthRepositoryImpl>());
    expect(Get.find<TaskRepository>(), isA<TaskRepositoryImpl>());
    expect(Get.isRegistered<ProfileRepository>(), isTrue);
    expect(Get.isRegistered<ProjectRepository>(), isTrue);
    expect(Get.isRegistered<DashboardRepository>(), isTrue);
    expect(Get.isRegistered<SyncRepository>(), isTrue);
  });

  test('registers every use case', () {
    final registered = <bool>[
      Get.isRegistered<LoginUseCase>(),
      Get.isRegistered<RegisterUseCase>(),
      Get.isRegistered<LogoutUseCase>(),
      Get.isRegistered<RestoreSessionUseCase>(),
      Get.isRegistered<ObserveSessionExpiryUseCase>(),
      Get.isRegistered<GetProfileUseCase>(),
      Get.isRegistered<UpdateProfileUseCase>(),
      Get.isRegistered<GetProjectsUseCase>(),
      Get.isRegistered<GetProjectUseCase>(),
      Get.isRegistered<GetTasksUseCase>(),
      Get.isRegistered<GetTaskUseCase>(),
      Get.isRegistered<CreateTaskUseCase>(),
      Get.isRegistered<UpdateTaskUseCase>(),
      Get.isRegistered<DeleteTaskUseCase>(),
      Get.isRegistered<GetThemeModeUseCase>(),
      Get.isRegistered<SetThemeModeUseCase>(),
      Get.isRegistered<GetAssigneesUseCase>(),
      Get.isRegistered<DiscardLocalChangesUseCase>(),
      Get.isRegistered<GetDashboardSummaryUseCase>(),
      Get.isRegistered<SyncPendingChangesUseCase>(),
      Get.isRegistered<ObservePendingChangesUseCase>(),
    ];
    expect(registered, everyElement(isTrue));
    expect(registered, hasLength(21));
  });

  test('controllers are available without route bindings', () {
    expect(Get.find<SessionController>().isSignedIn, isFalse);
    expect(Get.isRegistered<SplashController>(), isTrue);
    expect(Get.isRegistered<ThemeController>(), isTrue);
    expect(Get.isRegistered<DashboardController>(), isTrue);
    expect(Get.isRegistered<ProfileController>(), isTrue);
    expect(Get.isRegistered<TaskListController>(), isTrue);
    expect(Get.isRegistered<TaskDetailController>(), isTrue);
    expect(Get.isRegistered<TaskFormController>(), isTrue);
    expect(Get.isRegistered<ProjectListController>(), isTrue);
    expect(Get.isRegistered<ProjectDetailController>(), isTrue);
  });

  test('the session controller is a single shared instance', () {
    expect(Get.find<SessionController>(), same(Get.find<SessionController>()));
  });

  test('init uses the injected token storage', () async {
    await di.signIn();
    expect(await di.tokens.read(), isNotNull);
  });

  test('reset removes every registration so tests do not leak state', () async {
    await di.dispose();
    expect(Get.isRegistered<SessionController>(), isFalse);
    expect(Get.isRegistered<AuthRepository>(), isFalse);
    di = await TestDi.create();
    expect(Get.isRegistered<SessionController>(), isTrue);
  });
}
