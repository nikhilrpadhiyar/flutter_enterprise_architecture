import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;
import 'package:get/get.dart';

import '../core/config/app_config.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/console_app_logger.dart';
import '../core/messaging/app_messenger.dart';
import '../core/routes/navigation_logger.dart';
import '../core/utils/id_generator.dart';
import '../data/datasources/local/database/app_database.dart';
import '../data/datasources/local/pending_operation_ledger.dart';
import '../data/datasources/local/preferences_local_data_source.dart';
import '../data/datasources/local/session_local_data_source.dart';
import '../data/datasources/local/session_local_data_source_impl.dart';
import '../data/datasources/local/task_local_data_source.dart';
import '../data/datasources/local/task_local_data_source_impl.dart';
import '../data/datasources/local/user_data_cleaner.dart';
import '../data/datasources/remote/assignee_remote_data_source.dart';
import '../data/datasources/remote/auth_remote_data_source.dart';
import '../data/datasources/remote/auth_token_refresher.dart';
import '../data/datasources/remote/dashboard_remote_data_source.dart';
import '../data/datasources/remote/network_client_factory.dart';
import '../data/datasources/remote/profile_remote_data_source.dart';
import '../data/datasources/remote/project_remote_data_source.dart';
import '../data/datasources/remote/remote_requester.dart';
import '../data/datasources/remote/sync_remote_data_source.dart';
import '../data/datasources/remote/task_remote_data_source.dart';
import '../data/repositories/assignee_repository_impl.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/repositories/preferences_repository_impl.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../data/repositories/project_repository_impl.dart';
import '../data/repositories/sync_repository_impl.dart';
import '../data/repositories/task_repository_impl.dart';
import '../data/session/session_expiry_notifier.dart';
import '../data/sync/offline_sync_handler.dart';
import '../data/sync/queued_request_guard.dart';
import '../domain/repositories/assignee_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/repositories/preferences_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/repositories/sync_repository.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/usecases/create_task_use_case.dart';
import '../domain/usecases/delete_task_use_case.dart';
import '../domain/usecases/discard_local_changes_use_case.dart';
import '../domain/usecases/get_assignees_use_case.dart';
import '../domain/usecases/get_dashboard_summary_use_case.dart';
import '../domain/usecases/get_profile_use_case.dart';
import '../domain/usecases/get_project_use_case.dart';
import '../domain/usecases/get_projects_use_case.dart';
import '../domain/usecases/get_task_use_case.dart';
import '../domain/usecases/get_tasks_use_case.dart';
import '../domain/usecases/get_theme_mode_use_case.dart';
import '../domain/usecases/login_use_case.dart';
import '../domain/usecases/logout_use_case.dart';
import '../domain/usecases/observe_pending_changes_use_case.dart';
import '../domain/usecases/observe_session_expiry_use_case.dart';
import '../domain/usecases/register_use_case.dart';
import '../domain/usecases/restore_session_use_case.dart';
import '../domain/usecases/set_theme_mode_use_case.dart';
import '../domain/usecases/sync_pending_changes_use_case.dart';
import '../domain/usecases/update_profile_use_case.dart';
import '../domain/usecases/update_task_use_case.dart';
import '../features/auth/controllers/login_controller.dart';
import '../features/auth/controllers/register_controller.dart';
import '../features/auth/controllers/session_controller.dart';
import '../features/dashboard/controllers/dashboard_controller.dart';
import '../features/profile/controllers/profile_controller.dart';
import '../features/projects/controllers/project_detail_controller.dart';
import '../features/projects/controllers/project_list_controller.dart';
import '../features/settings/controllers/theme_controller.dart';
import '../features/splash/controllers/splash_controller.dart';
import '../features/tasks/controllers/task_detail_controller.dart';
import '../features/tasks/controllers/task_form_controller.dart';
import '../features/tasks/controllers/task_list_controller.dart';

/// Replacements for infrastructure, used by tests to avoid real storage,
/// connectivity and network access. Production passes none.
class GetDIOverrides {
  /// Creates a set of overrides. Every field is optional.
  const GetDIOverrides({
    this.logger,
    this.ids,
    this.messenger,
    this.database,
    this.tokenStorage,
    this.cacheStore,
    this.offlineQueueStore,
    this.connectivity,
    this.adapter,
    this.retryPolicy,
  });

  /// Replaces the console logger.
  final AppLogger? logger;

  /// Replaces the random id generator.
  final IdGenerator? ids;

  /// Replaces the snackbar messenger.
  final AppMessenger? messenger;

  /// Replaces the on-device SQLite database.
  final AppDatabase? database;

  /// Replaces the secure token storage.
  final fnp.TokenStorage? tokenStorage;

  /// Replaces the on-disk response cache.
  final fnp.CacheStore? cacheStore;

  /// Replaces the on-disk offline queue.
  final fnp.OfflineQueueStore? offlineQueueStore;

  /// Replaces the platform connectivity monitor.
  final fnp.ConnectivityMonitor? connectivity;

  /// Replaces the HTTP transport.
  final fnp.HttpClientAdapter? adapter;

  /// Replaces the retry policy.
  final fnp.RetryPolicy? retryPolicy;
}

/// The single composition root. Every dependency of the app is created and
/// wired here, in dependency order:
/// infrastructure, network, data sources, repositories, use cases,
/// controllers. Nothing else in the app constructs these objects, and no
/// route declares a binding.
class GetDI {
  const GetDI._();

  /// Registers all dependencies.
  ///
  /// [config] defaults to values from `--dart-define-from-file`. Tests pass
  /// [overrides] to swap infrastructure.
  static Future<void> init({
    AppConfig? config,
    GetDIOverrides overrides = const GetDIOverrides(),
  }) async {
    final appConfig = config ?? AppConfig.fromEnvironment();
    await _registerInfrastructure(appConfig, overrides);
    _registerNetwork(appConfig, overrides);
    _registerDataSources();
    _registerRepositories();
    _registerUseCases();
    _registerControllers();
    await Get.find<ThemeController>().load();
  }

  /// Shuts down the network client and database, then removes every
  /// registration. Used between tests.
  static Future<void> reset() async {
    if (Get.isRegistered<fnp.NetworkClient>()) {
      await Get.find<fnp.NetworkClient>().close(force: true);
    }
    if (Get.isRegistered<AppDatabase>()) {
      await Get.find<AppDatabase>().close();
    }
    Get.reset();
  }

  static Future<void> _registerInfrastructure(
    AppConfig config,
    GetDIOverrides overrides,
  ) async {
    final logger = overrides.logger ?? ConsoleAppLogger.forConfig(config);
    Get.put<AppConfig>(config, permanent: true);
    Get.put<AppLogger>(logger, permanent: true);
    Get.put<IdGenerator>(overrides.ids ?? RandomIdGenerator(), permanent: true);
    Get.put<NavigationLogger>(NavigationLogger(logger), permanent: true);
    Get.put<AppMessenger>(
      overrides.messenger ?? const SnackbarMessenger(),
      permanent: true,
    );
    Get.put<SessionExpiryNotifier>(SessionExpiryNotifier(), permanent: true);
    Get.put<fnp.TokenStorage>(
      overrides.tokenStorage ?? fnp.SecureTokenStorage(),
      permanent: true,
    );
    Get.put<fnp.CacheStore>(
      overrides.cacheStore ?? await fnp.DiskCacheStore.open(),
      permanent: true,
    );
    Get.put<fnp.OfflineQueueStore>(
      overrides.offlineQueueStore ?? await fnp.FileOfflineQueueStore.open(),
      permanent: true,
    );
    Get.put<fnp.ConnectivityMonitor>(
      overrides.connectivity ?? fnp.ConnectivityPlusMonitor(),
      permanent: true,
    );
    _registerLocalStorage(overrides);
  }

  /// The database and its local data sources have no network dependency, so
  /// they belong to infrastructure and are ready before the client is built.
  static void _registerLocalStorage(GetDIOverrides overrides) {
    final database =
        overrides.database ?? AppDatabase(driftDatabase(name: 'workspace'));
    final tasks = TaskLocalDataSourceImpl(database);
    final session = SessionLocalDataSourceImpl(database);
    Get.put<AppDatabase>(database, permanent: true);
    Get.put<TaskLocalDataSource>(tasks, permanent: true);
    Get.put<PendingOperationLedger>(tasks, permanent: true);
    Get.put<SessionLocalDataSource>(session, permanent: true);
    Get.put<PreferencesLocalDataSource>(
      PreferencesLocalDataSourceImpl(database),
      permanent: true,
    );
    Get.put<UserDataCleaner>(
      LocalUserDataCleaner(tasks, session, Get.find<fnp.CacheStore>()),
      permanent: true,
    );
  }

  static void _registerNetwork(AppConfig config, GetDIOverrides overrides) {
    final logger = Get.find<AppLogger>();
    final refresher = AuthTokenRefresher();
    final syncHandler = OfflineSyncHandler(
      Get.find<TaskLocalDataSource>(),
      logger,
    );
    Get.put<OfflineSyncHandler>(syncHandler, permanent: true);
    final client = NetworkClientFactory.create(
      config: config,
      tokenStorage: Get.find<fnp.TokenStorage>(),
      refresher: refresher,
      cacheStore: Get.find<fnp.CacheStore>(),
      offlineQueueStore: Get.find<fnp.OfflineQueueStore>(),
      connectivity: Get.find<fnp.ConnectivityMonitor>(),
      logger: logger,
      onAuthFailure: Get.find<SessionExpiryNotifier>().notify,
      interceptors: <fnp.Interceptor>[
        QueuedRequestGuard(Get.find<PendingOperationLedger>()),
      ],
      onReplayed: syncHandler.onReplayed,
      onDropped: syncHandler.onDropped,
      adapter: overrides.adapter,
      retryPolicy: overrides.retryPolicy ?? const fnp.RetryPolicy(),
    );
    Get.put<fnp.NetworkClient>(client, permanent: true);
    Get.put<RemoteRequester>(RemoteRequester(client, logger), permanent: true);
  }

  static void _registerDataSources() {
    final requester = Get.find<RemoteRequester>();
    Get.put<AuthRemoteDataSource>(
      AuthRemoteDataSource(requester, Get.find<fnp.TokenStorage>()),
      permanent: true,
    );
    Get.put<ProfileRemoteDataSource>(
      ProfileRemoteDataSource(requester),
      permanent: true,
    );
    Get.put<ProjectRemoteDataSource>(
      ProjectRemoteDataSource(requester),
      permanent: true,
    );
    Get.put<TaskRemoteDataSource>(
      TaskRemoteDataSource(requester),
      permanent: true,
    );
    Get.put<AssigneeRemoteDataSource>(
      AssigneeRemoteDataSource(requester),
      permanent: true,
    );
    Get.put<DashboardRemoteDataSource>(
      DashboardRemoteDataSource(requester),
      permanent: true,
    );
    Get.put<SyncRemoteDataSource>(
      SyncRemoteDataSource(Get.find<fnp.NetworkClient>()),
      permanent: true,
    );
  }

  static void _registerRepositories() {
    final logger = Get.find<AppLogger>();
    Get.put<AuthRepository>(
      AuthRepositoryImpl(
        Get.find<AuthRemoteDataSource>(),
        Get.find<SessionLocalDataSource>(),
        Get.find<UserDataCleaner>(),
        Get.find<SyncRemoteDataSource>(),
        Get.find<SessionExpiryNotifier>(),
        logger,
      ),
      permanent: true,
    );
    Get.put<ProfileRepository>(
      ProfileRepositoryImpl(
        Get.find<ProfileRemoteDataSource>(),
        Get.find<SessionLocalDataSource>(),
        logger,
      ),
      permanent: true,
    );
    Get.put<ProjectRepository>(
      ProjectRepositoryImpl(Get.find<ProjectRemoteDataSource>(), logger),
      permanent: true,
    );
    Get.put<TaskRepository>(
      TaskRepositoryImpl(
        Get.find<TaskRemoteDataSource>(),
        Get.find<TaskLocalDataSource>(),
        logger,
        Get.find<IdGenerator>(),
      ),
      permanent: true,
    );
    Get.put<AssigneeRepository>(
      AssigneeRepositoryImpl(Get.find<AssigneeRemoteDataSource>(), logger),
      permanent: true,
    );
    Get.put<PreferencesRepository>(
      PreferencesRepositoryImpl(Get.find<PreferencesLocalDataSource>()),
      permanent: true,
    );
    Get.put<DashboardRepository>(
      DashboardRepositoryImpl(Get.find<DashboardRemoteDataSource>(), logger),
      permanent: true,
    );
    Get.put<SyncRepository>(
      SyncRepositoryImpl(
        Get.find<SyncRemoteDataSource>(),
        Get.find<OfflineSyncHandler>(),
      ),
      permanent: true,
    );
  }

  static void _registerUseCases() {
    final logger = Get.find<AppLogger>();
    final auth = Get.find<AuthRepository>();
    final profile = Get.find<ProfileRepository>();
    final projects = Get.find<ProjectRepository>();
    final tasks = Get.find<TaskRepository>();
    final assignees = Get.find<AssigneeRepository>();
    final dashboard = Get.find<DashboardRepository>();
    final preferences = Get.find<PreferencesRepository>();
    final sync = Get.find<SyncRepository>();
    Get.put<LoginUseCase>(LoginUseCase(auth, logger), permanent: true);
    Get.put<RegisterUseCase>(RegisterUseCase(auth, logger), permanent: true);
    Get.put<LogoutUseCase>(LogoutUseCase(auth), permanent: true);
    Get.put<RestoreSessionUseCase>(
      RestoreSessionUseCase(auth),
      permanent: true,
    );
    Get.put<ObserveSessionExpiryUseCase>(
      ObserveSessionExpiryUseCase(auth),
      permanent: true,
    );
    Get.put<GetProfileUseCase>(GetProfileUseCase(profile), permanent: true);
    Get.put<UpdateProfileUseCase>(
      UpdateProfileUseCase(profile, logger),
      permanent: true,
    );
    Get.put<GetProjectsUseCase>(GetProjectsUseCase(projects), permanent: true);
    Get.put<GetProjectUseCase>(GetProjectUseCase(projects), permanent: true);
    Get.put<GetTasksUseCase>(GetTasksUseCase(tasks, logger), permanent: true);
    Get.put<GetTaskUseCase>(GetTaskUseCase(tasks), permanent: true);
    Get.put<CreateTaskUseCase>(
      CreateTaskUseCase(tasks, logger),
      permanent: true,
    );
    Get.put<UpdateTaskUseCase>(
      UpdateTaskUseCase(tasks, logger),
      permanent: true,
    );
    Get.put<DeleteTaskUseCase>(
      DeleteTaskUseCase(tasks, logger),
      permanent: true,
    );
    Get.put<GetAssigneesUseCase>(
      GetAssigneesUseCase(assignees),
      permanent: true,
    );
    Get.put<DiscardLocalChangesUseCase>(
      DiscardLocalChangesUseCase(tasks, logger),
      permanent: true,
    );
    Get.put<GetThemeModeUseCase>(
      GetThemeModeUseCase(preferences),
      permanent: true,
    );
    Get.put<SetThemeModeUseCase>(
      SetThemeModeUseCase(preferences),
      permanent: true,
    );
    Get.put<GetDashboardSummaryUseCase>(
      GetDashboardSummaryUseCase(dashboard),
      permanent: true,
    );
    Get.put<SyncPendingChangesUseCase>(
      SyncPendingChangesUseCase(sync),
      permanent: true,
    );
    Get.put<ObservePendingChangesUseCase>(
      ObservePendingChangesUseCase(sync),
      permanent: true,
    );
  }

  static void _registerControllers() {
    final session = Get.put<SessionController>(
      SessionController(
        Get.find<LogoutUseCase>(),
        Get.find<ObserveSessionExpiryUseCase>(),
        Get.find<AppLogger>(),
      ),
      permanent: true,
    );
    Get.lazyPut<LoginController>(
      () => LoginController(
        Get.find<LoginUseCase>(),
        session,
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<RegisterController>(
      () => RegisterController(
        Get.find<RegisterUseCase>(),
        session,
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.put<ThemeController>(
      ThemeController(
        Get.find<GetThemeModeUseCase>(),
        Get.find<SetThemeModeUseCase>(),
        Get.find<AppLogger>(),
      ),
      permanent: true,
    );
    Get.lazyPut<DashboardController>(
      () => DashboardController(
        Get.find<GetDashboardSummaryUseCase>(),
        session,
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ProfileController>(
      () => ProfileController(
        Get.find<GetProfileUseCase>(),
        Get.find<UpdateProfileUseCase>(),
        Get.find<ObservePendingChangesUseCase>(),
        session,
        Get.find<AppMessenger>(),
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<TaskListController>(
      () => TaskListController(
        Get.find<GetTasksUseCase>(),
        Get.find<ObservePendingChangesUseCase>(),
        Get.find<SyncPendingChangesUseCase>(),
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<TaskDetailController>(
      () => TaskDetailController(
        Get.find<GetTaskUseCase>(),
        Get.find<UpdateTaskUseCase>(),
        Get.find<DeleteTaskUseCase>(),
        Get.find<DiscardLocalChangesUseCase>(),
        Get.find<AppMessenger>(),
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<TaskFormController>(
      () => TaskFormController(
        Get.find<GetProjectsUseCase>(),
        Get.find<GetAssigneesUseCase>(),
        Get.find<GetTaskUseCase>(),
        Get.find<CreateTaskUseCase>(),
        Get.find<UpdateTaskUseCase>(),
        Get.find<AppMessenger>(),
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ProjectListController>(
      () => ProjectListController(
        Get.find<GetProjectsUseCase>(),
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ProjectDetailController>(
      () => ProjectDetailController(
        Get.find<GetProjectUseCase>(),
        Get.find<GetTasksUseCase>(),
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
    Get.lazyPut<SplashController>(
      () => SplashController(
        Get.find<RestoreSessionUseCase>(),
        session,
        Get.find<AppLogger>(),
      ),
      fenix: true,
    );
  }
}
