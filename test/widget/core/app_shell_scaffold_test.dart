import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_shell_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  const destinations = <AppDestination>[
    AppDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: '/home',
    ),
    AppDestination(
      label: 'Work',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      route: '/work',
    ),
  ];

  Widget shell({ValueChanged<int>? onSelected, int index = 0}) {
    return AppShellScaffold(
      destinations: destinations,
      currentIndex: index,
      onDestinationSelected: onSelected ?? (_) {},
      title: 'Title',
      body: const Text('Body'),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  testWidgets('phones get a bottom navigation bar', (tester) async {
    await pumpApp(tester, shell(), size: TestScreens.phone);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('tablets get a compact rail', (tester) async {
    await pumpApp(tester, shell(), size: TestScreens.tablet);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('large screens get an extended rail', (tester) async {
    await pumpApp(tester, shell(), size: TestScreens.desktop);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('selecting a destination reports its index', (tester) async {
    int? selected;
    await pumpApp(tester, shell(onSelected: (i) => selected = i));
    await tester.tap(find.text('Work'));
    expect(selected, 1);
  });

  testWidgets('rail destinations are selectable too', (tester) async {
    int? selected;
    await pumpApp(
      tester,
      shell(onSelected: (i) => selected = i),
      size: TestScreens.desktop,
    );
    await tester.tap(find.text('Work'));
    expect(selected, 1);
  });

  testWidgets('reflects the current index', (tester) async {
    await pumpApp(tester, shell(index: 1));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('content width is limited on very wide screens', (tester) async {
    await pumpApp(tester, shell(), size: const Size(2400, 900));
    final width = tester.getSize(find.text('Body')).width;
    expect(width, lessThan(2400));
  });
}
