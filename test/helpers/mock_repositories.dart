import 'package:flutter_enterprise_architecture/domain/repositories/auth_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/dashboard_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/profile_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/project_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/sync_repository.dart';
import 'package:flutter_enterprise_architecture/domain/repositories/task_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockSyncRepository extends Mock implements SyncRepository {}
