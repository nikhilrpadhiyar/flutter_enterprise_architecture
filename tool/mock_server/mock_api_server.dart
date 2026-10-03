/// A small in-memory implementation of `plans/docs/api-contract.md` for local
/// development and tests. Pure Dart, no dependencies.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'seed_data.dart';

/// Serves the REST API under `/v1`.
class MockApiServer {
  /// Creates a server. [accessTokenLifetime] controls how soon access tokens
  /// expire, which makes token refresh easy to exercise. [artificialDelay]
  /// slows every response so loading states are visible.
  MockApiServer({
    this.accessTokenLifetime = const Duration(minutes: 15),
    this.artificialDelay = Duration.zero,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _users = seedUsers();
    _projects = seedProjects(now);
    _tasks = seedTasks(now, _userById);
  }

  /// Lifetime of issued access tokens.
  final Duration accessTokenLifetime;

  /// Delay added to every response.
  final Duration artificialDelay;

  final DateTime Function() _clock;
  final Random _random = Random.secure();
  late final List<Json> _users;
  late final List<Json> _projects;
  late final List<Json> _tasks;
  final Map<String, ({String userId, DateTime expires})> _accessTokens = {};
  final Map<String, String> _refreshTokens = {};
  final Map<String, ({int status, Json body})> _idempotent = {};
  HttpServer? _server;
  int _nextTaskNumber = 1000;

  /// Port the server listens on (valid after [start]).
  int get port => _server!.port;

  /// Base URL clients should use.
  String get baseUrl => 'http://localhost:$port/v1';

  /// Starts listening. Use port 0 for a free port.
  Future<void> start({int port = 8080}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    unawaited(server.forEach(_handle));
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ---------------------------------------------------------------- routing

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _cors(response);
    try {
      if (artificialDelay > Duration.zero) {
        await Future<void>.delayed(artificialDelay);
      }
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        return;
      }
      final segments = request.uri.pathSegments;
      if (segments.isEmpty || segments.first != 'v1') {
        _error(response, 404, 'not_found', 'Unknown path');
        return;
      }
      final route = segments.skip(1).toList();
      final body = await _readBody(request);
      await _route(request, response, route, body);
    } on FormatException {
      _error(response, 400, 'validation_failed', 'Malformed JSON');
    } on Object {
      _error(response, 500, 'server_error', 'Unexpected error');
    } finally {
      await response.close();
    }
  }

  Future<void> _route(
    HttpRequest request,
    HttpResponse response,
    List<String> route,
    Json body,
  ) async {
    final method = request.method;
    final path = route.join('/');
    switch ((method, path)) {
      case ('POST', 'auth/register'):
        return _register(response, body);
      case ('POST', 'auth/login'):
        return _login(response, body);
      case ('POST', 'auth/refresh'):
        return _refresh(response, body);
    }
    final userId = _authenticate(request);
    if (userId == null) {
      _error(response, 401, 'unauthorized', 'Sign in required');
      return;
    }
    switch ((method, route)) {
      case ('POST', ['auth', 'logout']):
        _accessTokens.removeWhere((_, v) => v.userId == userId);
        _refreshTokens.removeWhere((_, v) => v == userId);
        response.statusCode = HttpStatus.noContent;
      case ('GET', ['profile']):
        _json(response, 200, _publicUser(_userById(userId)));
      case ('PATCH', ['profile']):
        _updateProfile(response, userId, body);
      case ('GET', ['users']):
        _listUsers(response, request.uri.queryParameters);
      case ('GET', ['projects']):
        _listProjects(response, request.uri.queryParameters);
      case ('GET', ['projects', final id]):
        _getProject(response, id);
      case ('GET', ['tasks']):
        _listTasks(response, request.uri.queryParameters);
      case ('POST', ['tasks']):
        _createTask(response, request, userId, body);
      case ('GET', ['tasks', final id]):
        _getTask(response, id);
      case ('PATCH', ['tasks', final id]):
        _updateTask(response, id, userId, body);
      case ('DELETE', ['tasks', final id]):
        _deleteTask(response, id);
      case ('GET', ['dashboard', 'summary']):
        _dashboard(response);
      default:
        _error(response, 404, 'not_found', 'Unknown endpoint');
    }
  }

  // ------------------------------------------------------------------- auth

  void _register(HttpResponse response, Json body) {
    final name = (body['name'] as String? ?? '').trim();
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final password = body['password'] as String? ?? '';
    final fields = <String, String>{
      if (name.isEmpty) 'name': 'Required',
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
        'email': 'Enter a valid email address',
      if (password.length < 8 ||
          !RegExp('[A-Za-z]').hasMatch(password) ||
          !RegExp('[0-9]').hasMatch(password))
        'password': 'Use at least 8 characters with a letter and a number',
    };
    if (fields.isEmpty && _users.any((u) => u['email'] == email)) {
      fields['email'] = 'Email is already registered';
    }
    if (fields.isNotEmpty) {
      _error(response, 422, 'validation_failed', 'Invalid input', fields);
      return;
    }
    final user = <String, Object?>{
      'id': 'u${_users.length + 1}',
      'name': name,
      'email': email,
      'phone': null,
      'role': 'member',
      'password': password,
    };
    _users.add(user);
    _json(response, 201, _session(user));
  }

  void _login(HttpResponse response, Json body) {
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final password = body['password'] as String? ?? '';
    final user = _users
        .where((u) => u['email'] == email && u['password'] == password)
        .firstOrNull;
    if (user == null) {
      _error(response, 401, 'unauthorized', 'Invalid email or password');
      return;
    }
    _json(response, 200, _session(user));
  }

  void _refresh(HttpResponse response, Json body) {
    final token = body['refreshToken'] as String? ?? '';
    final userId = _refreshTokens.remove(token);
    if (userId == null) {
      _error(response, 401, 'unauthorized', 'Invalid refresh token');
      return;
    }
    _json(response, 200, _issueTokens(userId));
  }

  Json _session(Json user) => <String, Object?>{
    ..._issueTokens(user['id']! as String),
    'user': _publicUser(user),
  };

  Json _issueTokens(String userId) {
    final access = _newToken();
    final refresh = _newToken();
    _accessTokens[access] = (
      userId: userId,
      expires: _clock().add(accessTokenLifetime),
    );
    _refreshTokens[refresh] = userId;
    return <String, Object?>{
      'accessToken': access,
      'refreshToken': refresh,
      'expiresIn': accessTokenLifetime.inSeconds,
    };
  }

  String? _authenticate(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return null;
    final entry = _accessTokens[header.substring('Bearer '.length)];
    if (entry == null || !entry.expires.isAfter(_clock())) return null;
    return entry.userId;
  }

  String _newToken() => List.generate(
    24,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  // ---------------------------------------------------------------- profile

  void _updateProfile(HttpResponse response, String userId, Json body) {
    final user = _userById(userId);
    final fields = <String, String>{};
    if (body.containsKey('name')) {
      final name = (body['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        fields['name'] = 'Required';
      } else {
        user['name'] = name;
      }
    }
    if (body.containsKey('phone')) user['phone'] = body['phone'];
    if (fields.isNotEmpty) {
      _error(response, 422, 'validation_failed', 'Invalid input', fields);
      return;
    }
    _json(response, 200, _publicUser(user));
  }

  Json _publicUser(Json user) => <String, Object?>{
    'id': user['id'],
    'name': user['name'],
    'email': user['email'],
    'phone': user['phone'],
    'role': user['role'],
  };

  Json _userById(String id) => _users.firstWhere((u) => u['id'] == id);

  void _listUsers(HttpResponse response, Map<String, String> query) {
    final items = _users
        .map((u) => <String, Object?>{'id': u['id'], 'name': u['name']})
        .toList();
    _json(response, 200, _page(items, query));
  }

  // --------------------------------------------------------------- projects

  void _listProjects(HttpResponse response, Map<String, String> query) {
    final q = (query['q'] ?? '').toLowerCase();
    final items = _projects
        .where((p) => q.isEmpty || '${p['name']}'.toLowerCase().contains(q))
        .map(_projectJson)
        .toList();
    _json(response, 200, _page(items, query));
  }

  void _getProject(HttpResponse response, String id) {
    final project = _projects.where((p) => p['id'] == id).firstOrNull;
    if (project == null) {
      _error(response, 404, 'not_found', 'Project not found');
      return;
    }
    _json(response, 200, _projectJson(project));
  }

  Json _projectJson(Json project) {
    final now = _clock();
    final tasks = _tasks.where((t) => t['projectId'] == project['id']).toList();
    final done = tasks.where((t) => t['status'] == 'done').length;
    final overdue = tasks.where((t) => _isOverdue(t, now)).length;
    return <String, Object?>{
      'id': project['id'],
      'name': project['name'],
      'description': project['description'],
      'status': project['status'],
      'ownerId': project['ownerId'],
      'taskCount': tasks.length,
      'overdueCount': overdue,
      'completedCount': done,
      'createdAt': project['createdAt'],
      'updatedAt': project['createdAt'],
    };
  }

  // ------------------------------------------------------------------ tasks

  void _listTasks(HttpResponse response, Map<String, String> query) {
    final q = (query['q'] ?? '').toLowerCase();
    final statuses = _csv(query['status']);
    final priorities = _csv(query['priority']);
    final projectId = query['projectId'];
    var tasks = _tasks.where((t) {
      if (q.isNotEmpty &&
          !'${t['title']} ${t['description']}'.toLowerCase().contains(q)) {
        return false;
      }
      if (statuses.isNotEmpty && !statuses.contains(t['status'])) return false;
      if (priorities.isNotEmpty && !priorities.contains(t['priority'])) {
        return false;
      }
      return projectId == null || t['projectId'] == projectId;
    }).toList();
    tasks = _sorted(tasks, query['sort'] ?? 'dueDate');
    _json(response, 200, _page(tasks.map(_taskJson).toList(), query));
  }

  List<Json> _sorted(List<Json> tasks, String sort) {
    int byDue(Json a, Json b) {
      final x = a['dueDate'] as String?;
      final y = b['dueDate'] as String?;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    }

    int rank(Json t) => _priorityOrder.indexOf(t['priority']! as String);
    return switch (sort) {
      '-dueDate' => tasks..sort((a, b) => -byDue(a, b)),
      'priority' => tasks..sort((a, b) => rank(b).compareTo(rank(a))),
      '-updatedAt' =>
        tasks
          ..sort((a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}')),
      _ => tasks..sort(byDue),
    };
  }

  void _getTask(HttpResponse response, String id) {
    final task = _taskById(id);
    if (task == null) {
      _error(response, 404, 'not_found', 'Task not found');
      return;
    }
    _json(response, 200, _taskJson(task));
  }

  void _createTask(
    HttpResponse response,
    HttpRequest request,
    String userId,
    Json body,
  ) {
    final key = request.headers.value('idempotency-key');
    final replay = key == null ? null : _idempotent[key];
    if (replay != null) {
      _json(response, replay.status, replay.body);
      return;
    }
    final fields = _validateTask(body, creating: true);
    if (fields.isNotEmpty) {
      _error(response, 422, 'validation_failed', 'Invalid input', fields);
      return;
    }
    final now = _clock().toIso8601String();
    final actor = _userById(userId)['name'];
    final task = <String, Object?>{
      'id': 't${_nextTaskNumber++}',
      'title': (body['title']! as String).trim(),
      'description': (body['description'] as String? ?? '').trim(),
      'status': 'todo',
      'priority': body['priority'],
      'projectId': body['projectId'],
      'assigneeId': body['assigneeId'],
      'dueDate': body['dueDate'],
      'attachments': <Json>[],
      'activity': <Json>[_activity('created', actor, 'created this task')],
      'createdAt': now,
      'updatedAt': now,
    };
    _tasks.add(task);
    final json = _taskJson(task);
    if (key != null) _idempotent[key] = (status: 201, body: json);
    _json(response, 201, json);
  }

  void _updateTask(HttpResponse response, String id, String userId, Json body) {
    final task = _taskById(id);
    if (task == null) {
      _error(response, 404, 'not_found', 'Task not found');
      return;
    }
    final fields = _validateTask(body, creating: false);
    if (fields.isNotEmpty) {
      _error(response, 422, 'validation_failed', 'Invalid input', fields);
      return;
    }
    final actor = _userById(userId)['name'];
    final activity = (task['activity']! as List<Object?>).cast<Json>();
    if (body.containsKey('status') && body['status'] != task['status']) {
      activity.add(
        _activity('statusChanged', actor, 'moved to ${body['status']}'),
      );
    }
    for (final key in const [
      'title',
      'description',
      'status',
      'priority',
      'assigneeId',
      'dueDate',
    ]) {
      if (body.containsKey(key)) task[key] = body[key];
    }
    if (body.keys.any((k) => k != 'status')) {
      activity.add(_activity('updated', actor, 'updated this task'));
    }
    task['updatedAt'] = _clock().toIso8601String();
    _json(response, 200, _taskJson(task));
  }

  void _deleteTask(HttpResponse response, String id) {
    final task = _taskById(id);
    if (task == null) {
      _error(response, 404, 'not_found', 'Task not found');
      return;
    }
    _tasks.remove(task);
    response.statusCode = HttpStatus.noContent;
  }

  Map<String, String> _validateTask(Json body, {required bool creating}) {
    final fields = <String, String>{};
    if (creating || body.containsKey('title')) {
      final title = (body['title'] as String? ?? '').trim();
      if (title.isEmpty) fields['title'] = 'Required';
      if (title.length > 120) fields['title'] = 'Too long';
    }
    if (creating && !_projects.any((p) => p['id'] == body['projectId'])) {
      fields['projectId'] = 'Unknown project';
    }
    if ((creating || body.containsKey('priority')) &&
        !_priorityOrder.contains(body['priority'])) {
      fields['priority'] = 'Invalid priority';
    }
    if (body.containsKey('status') &&
        !const ['todo', 'inProgress', 'done'].contains(body['status'])) {
      fields['status'] = 'Invalid status';
    }
    final assignee = body['assigneeId'];
    if (assignee != null && !_users.any((u) => u['id'] == assignee)) {
      fields['assigneeId'] = 'Unknown user';
    }
    final due = body['dueDate'];
    if (due != null && DateTime.tryParse('$due') == null) {
      fields['dueDate'] = 'Invalid date';
    }
    return fields;
  }

  Json? _taskById(String id) => _tasks.where((t) => t['id'] == id).firstOrNull;

  Json _taskJson(Json task) {
    final assigneeId = task['assigneeId'] as String?;
    return <String, Object?>{
      ...task,
      'assignee': assigneeId == null
          ? null
          : <String, Object?>{
              'id': assigneeId,
              'name': _userById(assigneeId)['name'],
            },
    }..remove('assigneeId');
  }

  Json _activity(String type, Object? actor, String message) =>
      <String, Object?>{
        'id': 'ac-${_random.nextInt(1 << 30)}',
        'actorName': actor,
        'type': type,
        'message': message,
        'createdAt': _clock().toIso8601String(),
      };

  bool _isOverdue(Json task, DateTime now) {
    final due = DateTime.tryParse('${task['dueDate']}');
    return due != null && task['status'] != 'done' && due.isBefore(now);
  }

  // -------------------------------------------------------------- dashboard

  void _dashboard(HttpResponse response) {
    final now = _clock();
    final open = _tasks.where((t) => t['status'] != 'done').toList();
    final done = _tasks.where((t) => t['status'] == 'done').toList();
    final pending = _sorted(List<Json>.of(open), 'dueDate').take(5);
    final completed = _sorted(List<Json>.of(done), '-updatedAt').take(5);
    final activity = [
      for (final task in _tasks)
        ...(task['activity']! as List<Object?>).cast<Json>(),
    ]..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    _json(response, 200, <String, Object?>{
      'projectCount': _projects.length,
      'openTaskCount': open.length,
      'completedTaskCount': done.length,
      'overdueTaskCount': open.where((t) => _isOverdue(t, now)).length,
      'pendingTasks': pending.map(_taskJson).toList(),
      'completedTasks': completed.map(_taskJson).toList(),
      'recentActivity': activity.take(5).toList(),
    });
  }

  // ---------------------------------------------------------------- helpers

  static const List<String> _priorityOrder = <String>[
    'low',
    'medium',
    'high',
    'urgent',
  ];

  Set<String> _csv(String? value) => value == null || value.isEmpty
      ? <String>{}
      : value.split(',').map((e) => e.trim()).toSet();

  Json _page(List<Json> items, Map<String, String> query) {
    final page = max(1, int.tryParse(query['page'] ?? '') ?? 1);
    final size = (int.tryParse(query['pageSize'] ?? '') ?? 20).clamp(1, 100);
    return <String, Object?>{
      'items': items.skip((page - 1) * size).take(size).toList(),
      'page': page,
      'pageSize': size,
      'total': items.length,
    };
  }

  Future<Json> _readBody(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.trim().isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) throw const FormatException();
    return decoded;
  }

  void _json(HttpResponse response, int status, Object body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }

  void _error(
    HttpResponse response,
    int status,
    String code,
    String message, [
    Map<String, String>? fields,
  ]) {
    _json(response, status, <String, Object?>{
      'error': <String, Object?>{
        'code': code,
        'message': message,
        'fields': ?fields,
      },
    });
  }

  void _cors(HttpResponse response) {
    response.headers
      ..set('access-control-allow-origin', '*')
      ..set(
        'access-control-allow-headers',
        'authorization, content-type, idempotency-key',
      )
      ..set(
        'access-control-allow-methods',
        'GET, POST, PATCH, DELETE, OPTIONS',
      );
  }
}
