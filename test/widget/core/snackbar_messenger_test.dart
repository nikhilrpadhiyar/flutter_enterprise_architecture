import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/messaging/app_messenger.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_durations.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<int> pumpShell(WidgetTester tester) async {
    var selected = 0;
    tester.view
      ..physicalSize = TestScreens.phone
      ..devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => const SnackbarMessenger().show('Task created'),
                child: const Text('Notify'),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: const <Widget>[
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.task), label: 'Tasks'),
              ],
            ),
          ),
        ),
      ),
    );
    return selected;
  }

  testWidgets('shows the message above the bottom navigation bar', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Notify'));
    await tester.pumpAndSettle();

    final snackBar = tester.getRect(find.byType(SnackBar));
    final navigation = tester.getRect(find.byType(NavigationBar));
    expect(find.text('Task created'), findsOneWidget);
    expect(snackBar.bottom, lessThanOrEqualTo(navigation.top));

    await tester.pump(AppDurations.snackbar + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('the navigation bar stays tappable while a message is shown', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Notify'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tasks'));
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);

    await tester.pump(AppDurations.snackbar + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('does nothing before the app has started', (tester) async {
    expect(() => const SnackbarMessenger().show('x'), returnsNormally);
  });
}
