import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _CounterController extends GetxController {
  int count = 0;
  static int created = 0;
  static int closed = 0;

  @override
  void onInit() {
    super.onInit();
    created++;
  }

  @override
  void onClose() {
    closed++;
    super.onClose();
  }
}

class _CounterPage extends StatelessWidget {
  const _CounterPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<_CounterController>(
        builder: (controller) => TextButton(
          onPressed: () {
            controller.count++;
            controller.update();
          },
          child: Text('count ${controller.count}'),
        ),
      ),
    );
  }
}

/// Documents how lazily registered controllers behave across page visits,
/// which the project relies on instead of route bindings.
void main() {
  setUp(() {
    Get.reset();
    _CounterController.created = 0;
    _CounterController.closed = 0;
    Get.lazyPut<_CounterController>(_CounterController.new, fenix: true);
  });

  tearDown(Get.reset);

  testWidgets('each visit gets a fresh controller that is closed on exit', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Get.to<void>(const _CounterPage()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    expect(_CounterController.created, 0);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(_CounterController.created, 1);
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    Get.back<void>();
    await tester.pumpAndSettle();
    expect(_CounterController.closed, 1);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(_CounterController.created, 2);
    expect(find.text('count 0'), findsOneWidget);
  });
}
