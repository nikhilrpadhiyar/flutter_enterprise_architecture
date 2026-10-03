/// JSON payloads matching `plans/docs/api-contract.md`.
library;

const String fixtureIso = '2026-10-02T12:00:00.000Z';

Map<String, Object?> userJson({String id = 'u1'}) => <String, Object?>{
  'id': id,
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'phone': null,
  'role': 'member',
};

Map<String, Object?> sessionJson({int expiresIn = 900}) => <String, Object?>{
  'accessToken': 'access-1',
  'refreshToken': 'refresh-1',
  'expiresIn': expiresIn,
  'user': userJson(),
};

Map<String, Object?> taskJson({
  String id = 't1',
  String title = 'Write spec',
  String status = 'todo',
  String priority = 'high',
  String projectId = 'p1',
  Object? assignee = const <String, Object?>{
    'id': 'u1',
    'name': 'Ada Lovelace',
  },
  Object? dueDate,
}) => <String, Object?>{
  'id': id,
  'title': title,
  'description': 'Draft the spec',
  'status': status,
  'priority': priority,
  'projectId': projectId,
  'assignee': assignee,
  'dueDate': dueDate,
  'attachments': <Object?>[
    <String, Object?>{
      'id': 'a1',
      'name': 'spec.pdf',
      'sizeBytes': 2048,
      'url': 'https://files.example.com/spec.pdf',
    },
  ],
  'activity': <Object?>[
    <String, Object?>{
      'id': 'ac1',
      'actorName': 'Ada Lovelace',
      'type': 'statusChanged',
      'message': 'moved to todo',
      'createdAt': fixtureIso,
    },
    <String, Object?>{
      'id': 'ac2',
      'actorName': 'Grace',
      'type': 'somethingNew',
      'message': 'did a new thing',
      'createdAt': fixtureIso,
    },
  ],
  'createdAt': fixtureIso,
  'updatedAt': fixtureIso,
};

Map<String, Object?> projectJson({String id = 'p1'}) => <String, Object?>{
  'id': id,
  'name': 'Launch',
  'description': 'Ship v1',
  'status': 'active',
  'ownerId': 'u1',
  'taskCount': 10,
  'overdueCount': 1,
  'completedCount': 4,
  'createdAt': fixtureIso,
  'updatedAt': fixtureIso,
};

Map<String, Object?> pageJson(
  List<Object?> items, {
  int page = 1,
  int pageSize = 20,
  int? total,
}) => <String, Object?>{
  'items': items,
  'page': page,
  'pageSize': pageSize,
  'total': total ?? items.length,
};

Map<String, Object?> dashboardJson() => <String, Object?>{
  'projectCount': 2,
  'openTaskCount': 5,
  'completedTaskCount': 7,
  'overdueTaskCount': 1,
  'pendingTasks': <Object?>[taskJson()],
  'completedTasks': <Object?>[taskJson(id: 't2', status: 'done')],
  'recentActivity': <Object?>[
    <String, Object?>{
      'id': 'ac1',
      'actorName': 'Ada',
      'type': 'created',
      'message': 'created a task',
      'createdAt': fixtureIso,
    },
  ],
};

Map<String, Object?> errorJson(
  String code, {
  Map<String, String>? fields,
}) => <String, Object?>{
  'error': <String, Object?>{'code': code, 'message': code, 'fields': ?fields},
};
