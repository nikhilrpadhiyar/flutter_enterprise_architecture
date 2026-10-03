import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/app.dart';
import 'package:flutter_enterprise_architecture/core/routes/route_names.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_di.dart';
import '../helpers/user_journey.dart';

/// The full user journey, run through the real app with the real dependency
/// graph, a fake backend behind the mock transport, and an in-memory database.
void main() {
  late TestDi di;
  late FakeBackend backend;

  setUp(() async {
    di = await TestDi.create();
    backend = FakeBackend(di.adapter);
  });
  tearDown(() => di.dispose());

  Future<void> run(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MyApp());
    await settleApp(tester);

    await runUserJourney(
      tester,
      settle: () => settleApp(tester),
      email: 'demo@example.com',
      password: 'Password1',
      projectName: 'Platform migration',
    );

    expect(Get.currentRoute, RouteNames.login);
    expect(await di.tokens.read(), isNull);
    final created = backend.tasks.firstWhere(
      (t) => t['title'] == 'Journey task renamed',
    );
    expect(created['status'], TaskStatus.done.name);
    expect(created['projectId'], 'p2');
  }

  testWidgets('works on a phone', (tester) => run(tester, TestScreens.phone));

  testWidgets('works on a tablet', (tester) => run(tester, TestScreens.tablet));

  testWidgets(
    'works on a desktop',
    (tester) => run(tester, TestScreens.desktop),
  );
}
