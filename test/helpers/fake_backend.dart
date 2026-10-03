import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import 'json_fixtures.dart';
import 'test_network.dart';

/// A small in-memory API behind the mock transport, so widget tests can run
/// complete flows: listing with filters and paging, creating, editing and
/// deleting. It follows `plans/docs/api-contract.md`.
class FakeBackend {
  FakeBackend(this.adapter, {List<Map<String, Object?>>? tasks})
    : tasks = tasks ?? <Map<String, Object?>>[taskJson()] {
    adapter
      ..onGet(TestNetwork.path('tasks'), _listTasks)
      ..onPost(TestNetwork.path('tasks'), _createTask)
      ..onGet(RegExp(r'/v1/tasks/[^/]+$'), _getTask)
      ..onPatch(RegExp(r'/v1/tasks/[^/]+$'), _updateTask)
      ..onDelete(RegExp(r'/v1/tasks/[^/]+$'), _deleteTask)
      ..onGet(TestNetwork.path('projects'), _listProjects)
      ..onGet(RegExp(r'/v1/projects/[^/]+$'), _getProject)
      ..onPost(TestNetwork.path('auth/login'), _login)
      ..onGet(TestNetwork.path('users'), _listUsers)
      ..onGet(TestNetwork.path('dashboard/summary'), _dashboard)
      ..onGet(TestNetwork.path('profile'), _getProfile)
      ..onPatch(TestNetwork.path('profile'), _updateProfile)
      ..onPost(
        TestNetwork.path('auth/logout'),
        (call) => offline
            ? _down()
            : fnp.MockResponse.bytes(Uint8List(0), statusCode: 204),
      );
  }

  final fnp.MockHttpClientAdapter adapter;

  /// Tasks the server holds.
  final List<Map<String, Object?>> tasks;

  /// Projects the server holds.
  final List<Map<String, Object?>> projects = <Map<String, Object?>>[
    projectJson(),
    projectJson(id: 'p2')..['name'] = 'Platform migration',
  ];

  /// People that can be assigned.
  final List<Map<String, Object?>> users = <Map<String, Object?>>[
    <String, Object?>{'id': 'u1', 'name': 'Ada Lovelace'},
    <String, Object?>{'id': 'u2', 'name': 'Grace Hopper'},
  ];

  /// The signed-in user's profile.
  final Map<String, Object?> profile = userJson();

  /// When true every request fails like a lost connection.
  bool offline = false;

  /// When set, task list requests wait until it completes, so tests can
  /// observe the loading state.
  Completer<void>? holdTaskList;

  /// When set, profile updates wait until it completes.
  Completer<void>? holdProfileWrite;

  /// Status code to answer task reads with instead of success.
  int? failReadsWith;

  /// Status code to answer task writes with instead of success.
  int? failWritesWith;

  int _nextId = 100;

  fnp.MockResponse _down() =>
      fnp.MockResponse.failure(const fnp.ConnectionException());

  Map<String, String> _query(fnp.RecordedCall call) => call.uri.queryParameters;

  fnp.MockResponse _page(List<Object?> items, Map<String, String> query) {
    final page = int.parse(query['page'] ?? '1');
    final size = int.parse(query['pageSize'] ?? '20');
    return fnp.MockResponse.json(
      pageJson(
        items.skip((page - 1) * size).take(size).toList(),
        page: page,
        pageSize: size,
        total: items.length,
      ),
    );
  }

  Future<fnp.MockResponse> _listTasks(fnp.RecordedCall call) async {
    await holdTaskList?.future;
    if (offline) return _down();
    final readFailure = failReadsWith;
    if (readFailure != null) {
      return fnp.MockResponse.json(
        errorJson('forbidden'),
        statusCode: readFailure,
      );
    }
    final query = _query(call);
    final q = (query['q'] ?? '').toLowerCase();
    final statuses = (query['status'] ?? '').split(',').where((s) => s != '');
    final priorities = (query['priority'] ?? '')
        .split(',')
        .where((s) => s != '');
    final projectId = query['projectId'];
    final items = tasks.where((t) {
      if (q.isNotEmpty && !'${t['title']}'.toLowerCase().contains(q)) {
        return false;
      }
      if (statuses.isNotEmpty && !statuses.contains(t['status'])) return false;
      if (priorities.isNotEmpty && !priorities.contains(t['priority'])) {
        return false;
      }
      return projectId == null || t['projectId'] == projectId;
    }).toList();
    return _page(items, query);
  }

  fnp.MockResponse _getTask(fnp.RecordedCall call) {
    if (offline) return _down();
    final task = _find(call);
    return task == null ? _notFound() : fnp.MockResponse.json(task);
  }

  fnp.MockResponse _createTask(fnp.RecordedCall call) {
    if (offline) return _down();
    final failure = _writeFailure();
    if (failure != null) return failure;
    final body = call.bodyJson! as Map<String, Object?>;
    final task = taskJson(
      id: 'srv-${_nextId++}',
      title: body['title']! as String,
      priority: body['priority']! as String,
      projectId: body['projectId']! as String,
      assignee: null,
      dueDate: body['dueDate'],
    )..['description'] = body['description'];
    tasks.insert(0, task);
    return fnp.MockResponse.json(task, statusCode: 201);
  }

  fnp.MockResponse _updateTask(fnp.RecordedCall call) {
    if (offline) return _down();
    final failure = _writeFailure();
    if (failure != null) return failure;
    final task = _find(call);
    if (task == null) return _notFound();
    task.addAll((call.bodyJson! as Map<String, Object?>)..remove('assigneeId'));
    return fnp.MockResponse.json(task);
  }

  fnp.MockResponse _deleteTask(fnp.RecordedCall call) {
    if (offline) return _down();
    final failure = _writeFailure();
    if (failure != null) return failure;
    final task = _find(call);
    if (task == null) return _notFound();
    tasks.remove(task);
    return fnp.MockResponse.bytes(Uint8List(0), statusCode: 204);
  }

  fnp.MockResponse _listProjects(fnp.RecordedCall call) {
    if (offline) return _down();
    final query = _query(call);
    final q = (query['q'] ?? '').toLowerCase();
    return _page(
      projects.where((p) => '${p['name']}'.toLowerCase().contains(q)).toList(),
      query,
    );
  }

  fnp.MockResponse _getProject(fnp.RecordedCall call) {
    if (offline) return _down();
    final id = call.uri.pathSegments.last;
    final project = projects.where((p) => p['id'] == id).firstOrNull;
    return project == null ? _notFound() : fnp.MockResponse.json(project);
  }

  fnp.MockResponse _listUsers(fnp.RecordedCall call) {
    if (offline) return _down();
    return _page(users, _query(call));
  }

  fnp.MockResponse _login(fnp.RecordedCall call) {
    if (offline) return _down();
    final body = call.bodyJson! as Map<String, Object?>;
    if (body['password'] != 'Password1') {
      return fnp.MockResponse.json(errorJson('unauthorized'), statusCode: 401);
    }
    return fnp.MockResponse.json(<String, Object?>{
      ...sessionJson(),
      'user': profile,
    });
  }

  fnp.MockResponse _dashboard(fnp.RecordedCall call) {
    if (offline) return _down();
    return dashboardResponse();
  }

  /// The dashboard summary for the current tasks.
  fnp.MockResponse dashboardResponse() {
    final now = DateTime.now();
    final open = tasks.where((t) => t['status'] != 'done').toList();
    final done = tasks.where((t) => t['status'] == 'done').toList();
    final overdue = open.where((t) {
      final due = DateTime.tryParse('${t['dueDate']}');
      return due != null && due.isBefore(now);
    });
    final activity = <Object?>[
      for (final task in tasks) ...(task['activity']! as List<Object?>),
    ];
    return fnp.MockResponse.json(<String, Object?>{
      'projectCount': projects.length,
      'openTaskCount': open.length,
      'completedTaskCount': done.length,
      'overdueTaskCount': overdue.length,
      'pendingTasks': open.take(5).toList(),
      'completedTasks': done.take(5).toList(),
      'recentActivity': activity.take(5).toList(),
    });
  }

  fnp.MockResponse _getProfile(fnp.RecordedCall call) {
    if (offline) return _down();
    return fnp.MockResponse.json(profile);
  }

  Future<fnp.MockResponse> _updateProfile(fnp.RecordedCall call) async {
    await holdProfileWrite?.future;
    if (offline) return _down();
    final failure = _writeFailure(field: 'name');
    if (failure != null) return failure;
    profile.addAll(call.bodyJson! as Map<String, Object?>);
    return fnp.MockResponse.json(profile);
  }

  Map<String, Object?>? _find(fnp.RecordedCall call) {
    final id = call.uri.pathSegments.last;
    return tasks.where((t) => t['id'] == id).firstOrNull;
  }

  fnp.MockResponse _notFound() =>
      fnp.MockResponse.json(errorJson('not_found'), statusCode: 404);

  fnp.MockResponse? _writeFailure({String field = 'title'}) {
    final status = failWritesWith;
    if (status == null) return null;
    final body = status == 422
        ? errorJson(
            'validation_failed',
            fields: <String, String>{field: 'Server says no'},
          )
        : errorJson('server_error');
    return fnp.MockResponse.json(body, statusCode: status);
  }

  /// Requests the app made to [suffix], oldest first.
  List<fnp.RecordedCall> callsTo(String suffix) => adapter.capturedRequests
      .where((c) => c.uri.path.endsWith(suffix))
      .toList();

  /// Builds `count` numbered tasks for paging tests.
  static List<Map<String, Object?>> manyTasks(int count) =>
      <Map<String, Object?>>[
        for (var i = 1; i <= count; i++) taskJson(id: 't$i', title: 'Task $i'),
      ];

  /// Decodes a request body, for assertions.
  static Object? bodyOf(fnp.RecordedCall call) =>
      call.bodyText.isEmpty ? null : jsonDecode(call.bodyText);
}

/// Canned dashboard responses for tests that replace the default route.
abstract final class FakeDashboard {
  /// The same summary the fake backend would serve.
  static fnp.MockResponse response(FakeBackend backend) =>
      backend.dashboardResponse();

  /// A 403 error.
  static fnp.MockResponse forbidden() =>
      fnp.MockResponse.json(errorJson('forbidden'), statusCode: 403);
}
