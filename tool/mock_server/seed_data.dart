/// Demo data served by the mock API. Pure Dart, no Flutter imports.
library;

typedef Json = Map<String, Object?>;

/// Credentials of the demo account.
const String demoEmail = 'demo@example.com';

/// Password of every seeded account.
const String demoPassword = 'Password1';

/// Seeded user records (including passwords, never sent to clients).
List<Json> seedUsers() => <Json>[
  <String, Object?>{
    'id': 'u1',
    'name': 'Ada Lovelace',
    'email': demoEmail,
    'phone': '+44 20 7946 0001',
    'role': 'manager',
    'password': demoPassword,
  },
  <String, Object?>{
    'id': 'u2',
    'name': 'Grace Hopper',
    'email': 'grace@example.com',
    'phone': null,
    'role': 'member',
    'password': demoPassword,
  },
  <String, Object?>{
    'id': 'u3',
    'name': 'Linus Torvalds',
    'email': 'linus@example.com',
    'phone': null,
    'role': 'member',
    'password': demoPassword,
  },
];

/// Seeded projects (counts are computed from tasks at request time).
List<Json> seedProjects(DateTime now) => <Json>[
  <String, Object?>{
    'id': 'p1',
    'name': 'Mobile app launch',
    'description': 'Ship the first public release of the mobile app.',
    'status': 'active',
    'ownerId': 'u1',
    'createdAt': now.subtract(const Duration(days: 60)).toIso8601String(),
  },
  <String, Object?>{
    'id': 'p2',
    'name': 'Platform migration',
    'description': 'Move services to the new infrastructure.',
    'status': 'active',
    'ownerId': 'u2',
    'createdAt': now.subtract(const Duration(days: 45)).toIso8601String(),
  },
  <String, Object?>{
    'id': 'p3',
    'name': 'Security review',
    'description': 'Annual audit and remediation work.',
    'status': 'onHold',
    'ownerId': 'u1',
    'createdAt': now.subtract(const Duration(days: 30)).toIso8601String(),
  },
];

const List<String> _titles = <String>[
  'Design onboarding flow',
  'Set up CI pipeline',
  'Write API documentation',
  'Fix login timeout bug',
  'Review pull requests',
  'Prepare release notes',
  'Migrate user database',
  'Add push notifications',
  'Audit third party packages',
  'Improve search performance',
  'Create dashboard widgets',
  'Update privacy policy',
];

const List<String> _statuses = <String>['todo', 'inProgress', 'done'];
const List<String> _priorities = <String>['low', 'medium', 'high', 'urgent'];
const List<String> _assignees = <String>['u1', 'u2', 'u3'];

/// Seeded tasks spread across projects, statuses and deadlines.
List<Json> seedTasks(DateTime now, Json Function(String id) userById) {
  final tasks = <Json>[];
  for (var i = 0; i < 36; i++) {
    final id = 't${i + 1}';
    final status = _statuses[i % _statuses.length];
    final created = now.subtract(Duration(days: 40 - i));
    final assigneeId = i % 7 == 0 ? null : _assignees[i % _assignees.length];
    tasks.add(<String, Object?>{
      'id': id,
      'title': '${_titles[i % _titles.length]} ${i ~/ _titles.length + 1}',
      'description': 'Details for task ${i + 1}.',
      'status': status,
      'priority': _priorities[(i * 3) % _priorities.length],
      'projectId': 'p${i % 3 + 1}',
      'assigneeId': assigneeId,
      'dueDate': i % 5 == 0
          ? null
          : now.add(Duration(days: i % 14 - 4)).toIso8601String(),
      'attachments': i % 4 == 0
          ? <Json>[
              <String, Object?>{
                'id': 'a$id',
                'name': 'notes-$id.pdf',
                'sizeBytes': 20480 + i * 100,
                'url': 'https://files.example.com/notes-$id.pdf',
              },
            ]
          : <Json>[],
      'activity': <Json>[
        <String, Object?>{
          'id': 'ac-$id-1',
          'actorName': userById(assigneeId ?? 'u1')['name'],
          'type': 'created',
          'message': 'created this task',
          'createdAt': created.toIso8601String(),
        },
      ],
      'createdAt': created.toIso8601String(),
      'updatedAt': created.add(Duration(hours: i)).toIso8601String(),
    });
  }
  return tasks;
}
