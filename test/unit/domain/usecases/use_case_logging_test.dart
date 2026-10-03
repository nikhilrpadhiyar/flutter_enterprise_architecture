import 'package:flutter_enterprise_architecture/core/error/failure.dart';
import 'package:flutter_enterprise_architecture/core/logging/console_app_logger.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_priority.dart';
import 'package:flutter_enterprise_architecture/domain/requests/create_task_request.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/create_task_use_case.dart';
import 'package:flutter_enterprise_architecture/domain/usecases/login_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late List<String> lines;
  late ConsoleAppLogger logger;

  setUp(() {
    lines = <String>[];
    logger = ConsoleAppLogger(sink: lines.add);
  });

  test('a use case logs what it is doing, without the user input', () async {
    final useCase = LoginUseCase(MockAuthRepository(), logger);

    await expectLater(
      useCase(email: 'secret@example.com', password: 'hunter2'),
      throwsA(isA<Object>()),
    );

    expect(lines, contains('[DEBUG] [usecase] login'));
    expect(lines.join(), isNot(contains('secret@example.com')));
    expect(lines.join(), isNot(contains('hunter2')));
  });

  test('logging is optional', () async {
    final useCase = CreateTaskUseCase(MockTaskRepository());
    await expectLater(
      useCase(
        const CreateTaskRequest(
          title: ' ',
          projectId: 'p1',
          priority: TaskPriority.low,
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
