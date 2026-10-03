import 'package:flutter_enterprise_architecture/data/models/dashboard_summary_model.dart';
import 'package:flutter_enterprise_architecture/data/models/paged_model.dart';
import 'package:flutter_enterprise_architecture/data/models/project_model.dart';
import 'package:flutter_enterprise_architecture/data/models/requests/request_bodies.dart';
import 'package:flutter_enterprise_architecture/data/models/session_model.dart';
import 'package:flutter_enterprise_architecture/data/models/task_model.dart';
import 'package:flutter_enterprise_architecture/data/models/user_model.dart';
import 'package:flutter_enterprise_architecture/domain/entities/activity_item.dart';
import 'package:flutter_enterprise_architecture/domain/entities/project_status.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_enterprise_architecture/domain/entities/user_role.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_profile_request.dart';
import 'package:flutter_enterprise_architecture/domain/requests/update_task_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/json_fixtures.dart';

void main() {
  group('TaskModel', () {
    test('parses every field into an entity', () {
      final task = TaskModel.fromJson(
        taskJson(dueDate: '2026-10-05T00:00:00.000Z'),
      ).toEntity();

      expect(task.id, 't1');
      expect(task.status, TaskStatus.todo);
      expect(task.priority, TaskPriority.high);
      expect(task.assignee?.name, 'Ada Lovelace');
      expect(task.dueDate, DateTime.utc(2026, 10, 5));
      expect(task.attachments.single.sizeBytes, 2048);
      expect(task.activity, hasLength(2));
    });

    test('maps unknown activity types to other', () {
      final task = TaskModel.fromJson(taskJson()).toEntity();
      expect(task.activity.first.type, ActivityType.statusChanged);
      expect(task.activity.last.type, ActivityType.other);
    });

    test('tolerates a missing description, assignee and lists', () {
      final json = taskJson()
        ..remove('description')
        ..remove('attachments')
        ..remove('activity')
        ..['assignee'] = null;
      final task = TaskModel.fromJson(json).toEntity();
      expect(task.description, isEmpty);
      expect(task.assignee, isNull);
      expect(task.attachments, isEmpty);
      expect(task.activity, isEmpty);
    });

    test('rejects an unknown status', () {
      expect(
        () => TaskModel.fromJson(taskJson(status: 'archived')),
        throwsFormatException,
      );
    });

    test('rejects a missing required field and wrong types', () {
      expect(
        () => TaskModel.fromJson(taskJson()..remove('title')),
        throwsFormatException,
      );
      expect(() => TaskModel.fromJson('not an object'), throwsFormatException);
    });
  });

  group('other models', () {
    test('UserModel parses roles', () {
      expect(UserModel.fromJson(userJson()).toEntity().role, UserRole.member);
      expect(
        () => UserModel.fromJson(userJson()..['role'] = 'owner'),
        throwsFormatException,
      );
    });

    test('ProjectModel computes entity fields', () {
      final project = ProjectModel.fromJson(projectJson()).toEntity();
      expect(project.status, ProjectStatus.active);
      expect(project.progress, 0.4);
    });

    test('PagedModel converts items and exposes paging', () {
      final page = PagedModel<ProjectModel>.fromJson(
        pageJson(<Object?>[projectJson()], total: 41),
        ProjectModel.fromJson,
      ).toEntity((model) => model.toEntity());
      expect(page.items, hasLength(1));
      expect(page.total, 41);
      expect(page.hasMore, isTrue);
    });

    test('PagedModel rejects a missing items list', () {
      expect(
        () => PagedModel<ProjectModel>.fromJson(<String, Object?>{
          'page': 1,
          'pageSize': 1,
          'total': 0,
        }, ProjectModel.fromJson),
        throwsFormatException,
      );
    });

    test('DashboardSummaryModel parses nested lists', () {
      final summary = DashboardSummaryModel.fromJson(dashboardJson())
          .toEntity();
      expect(summary.openTaskCount, 5);
      expect(summary.pendingTasks.single.id, 't1');
      expect(summary.completedTasks.single.status, TaskStatus.done);
      expect(summary.recentActivity.single.type, ActivityType.created);
    });

    test('SessionModel reads tokens and user, and computes expiry', () {
      final session = SessionModel.fromJson(sessionJson(expiresIn: 60));
      expect(session.user.email, 'ada@example.com');
      final now = DateTime.utc(2026, 1, 1);
      expect(
        session.tokens.expiresAt(now),
        now.add(const Duration(seconds: 60)),
      );
    });
  });

  group('RequestBodies', () {
    test('createTask sends only provided optional fields', () {
      final body = RequestBodies.createTask(
        const CreateTaskRequest(
          title: 'T',
          projectId: 'p1',
          priority: TaskPriority.urgent,
        ),
      );
      expect(body, <String, Object?>{
        'title': 'T',
        'description': '',
        'projectId': 'p1',
        'priority': 'urgent',
      });
    });

    test('createTask serialises the deadline in UTC', () {
      final body = RequestBodies.createTask(
        CreateTaskRequest(
          title: 'T',
          projectId: 'p1',
          priority: TaskPriority.low,
          assigneeId: 'u2',
          dueDate: DateTime.utc(2026, 10, 5),
        ),
      );
      expect(body['dueDate'], '2026-10-05T00:00:00.000Z');
      expect(body['assigneeId'], 'u2');
    });

    test('updateTask sends only changes and can clear the deadline', () {
      expect(
        RequestBodies.updateTask(
          const UpdateTaskRequest(status: TaskStatus.done),
        ),
        <String, Object?>{'status': 'done'},
      );
      expect(
        RequestBodies.updateTask(const UpdateTaskRequest(clearDueDate: true)),
        <String, Object?>{'dueDate': null},
      );
    });

    test('updateProfile sends only provided fields', () {
      expect(
        RequestBodies.updateProfile(const UpdateProfileRequest(phone: '5')),
        <String, Object?>{'phone': '5'},
      );
    });
  });
}
