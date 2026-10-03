import 'package:flutter_enterprise_architecture/domain/entities/project.dart';
import 'package:flutter_enterprise_architecture/domain/entities/project_status.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/domain/entities/user.dart';
import 'package:flutter_enterprise_architecture/domain/entities/user_role.dart';

/// Fixed reference time so tests do not depend on the wall clock.
final DateTime fixtureNow = DateTime.utc(2026, 10, 2, 12);

User buildUser({String id = 'u1'}) => User(
  id: id,
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  role: UserRole.member,
);

Task buildTask({
  String id = 't1',
  TaskStatus status = TaskStatus.todo,
  DateTime? dueDate,
}) => Task(
  id: id,
  title: 'Write spec',
  description: 'Draft the spec',
  status: status,
  priority: TaskPriority.medium,
  projectId: 'p1',
  dueDate: dueDate,
  createdAt: fixtureNow,
  updatedAt: fixtureNow,
);

Project buildProject({int taskCount = 10, int completedCount = 4}) => Project(
  id: 'p1',
  name: 'Launch',
  description: 'Ship v1',
  status: ProjectStatus.active,
  ownerId: 'u1',
  taskCount: taskCount,
  overdueCount: 1,
  completedCount: completedCount,
  createdAt: fixtureNow,
  updatedAt: fixtureNow,
);
