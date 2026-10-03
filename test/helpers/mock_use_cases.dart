import 'package:flutter_enterprise_architecture/domain/usecases/get_tasks_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/login_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/logout_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_pending_changes_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/observe_session_expiry_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/register_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/sync_pending_changes_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockObserveSessionExpiryUseCase extends Mock
    implements ObserveSessionExpiryUseCase {}

class MockGetTasksUseCase extends Mock implements GetTasksUseCase {}

class MockObservePendingChangesUseCase extends Mock
    implements ObservePendingChangesUseCase {}

class MockSyncPendingChangesUseCase extends Mock
    implements SyncPendingChangesUseCase {}
