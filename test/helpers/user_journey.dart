import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the whole app like a user: sign in, create a task, find it, view it,
/// change it, edit it, and sign out.
///
/// The same journey runs against a fake backend in `flutter test` and against
/// the real mock server on a device. [settle] waits for loading to finish and
/// is supplied by each environment because they differ in how time passes.
/// [projectName] is the project to pick in the form.
Future<void> runUserJourney(
  WidgetTester tester, {
  required Future<void> Function() settle,
  required String email,
  required String password,
  required String projectName,
  String firstName = 'Ada',
}) async {
  const title = 'Journey task';
  const renamed = 'Journey task renamed';

  Future<void> tapLabelInNavigation(String label) async {
    final scope = find.byType(NavigationBar).evaluate().isNotEmpty
        ? find.byType(NavigationBar)
        : find.byType(NavigationRail);
    await tester.tap(find.descendant(of: scope, matching: find.text(label)));
    await settle();
  }

  Future<void> pickFrom<T>(String option) async {
    final dropdown = find.byType(DropdownButtonFormField<T>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  /// Scrolls [button] into view and taps it.
  ///
  /// On a device, typing brings up the real keyboard, which shrinks the
  /// visible area only after it finishes animating. Waiting for that first
  /// keeps the button from ending up underneath it.
  Future<void> tapButton(Finder button) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
  }

  /// A task title inside the list, not the search box that may hold it too.
  Finder inList(String text) =>
      find.descendant(of: find.byType(ListView), matching: find.text(text));

  // 1. The app starts signed out and asks for credentials.
  expect(find.text(AppStrings.signInTitle), findsOneWidget);
  await tester.enterText(field(AppStrings.emailLabel), email);
  await tester.enterText(field(AppStrings.passwordLabel), password);
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.signIn));
  await settle();

  // 2. The dashboard greets the user.
  expect(find.text(AppStrings.greeting(firstName)), findsOneWidget);
  expect(find.text(AppStrings.pendingTasks), findsOneWidget);

  // 3. Create a task from the dashboard shortcut.
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.newTask));
  await settle();
  await tester.enterText(field(AppStrings.taskTitleLabel), title);
  await tester.enterText(
    field(AppStrings.descriptionLabel),
    'Made by the journey',
  );
  await pickFrom<String>(projectName);
  await tapButton(find.widgetWithText(FilledButton, AppStrings.newTask).last);
  await settle();
  expect(find.text(AppStrings.greeting(firstName)), findsOneWidget);

  // 4. Find it in the task list by searching.
  await tapLabelInNavigation(AppStrings.navTasks);
  await tester.enterText(
    find.widgetWithText(TextField, AppStrings.searchTasks),
    title,
  );
  await tester.pump(const Duration(milliseconds: 500));
  await settle();
  expect(inList(title), findsOneWidget);

  // 5. View it, then mark it done.
  await tester.tap(inList(title));
  await settle();
  expect(find.text(AppStrings.taskDetailTitle), findsOneWidget);
  expect(find.text('Made by the journey'), findsOneWidget);
  await tester.tap(find.byType(DropdownButtonFormField<TaskStatus>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.statusDone).last);
  await settle();
  expect(find.text(AppStrings.statusDone), findsOneWidget);

  // 6. Edit the title.
  await tester.tap(find.byTooltip(AppStrings.edit));
  await settle();
  await tester.enterText(field(AppStrings.taskTitleLabel), renamed);
  await tapButton(find.widgetWithText(FilledButton, AppStrings.saveChanges));
  await settle();
  expect(find.text(renamed), findsWidgets);

  // 7. Back on the list the renamed task is shown.
  await tester.pageBack();
  await settle();
  await tester.enterText(
    find.widgetWithText(TextField, AppStrings.searchTasks),
    renamed,
  );
  await tester.pump(const Duration(milliseconds: 500));
  await settle();
  expect(inList(renamed), findsOneWidget);

  // 8. Sign out from the profile.
  await tapLabelInNavigation(AppStrings.navProfile);
  await tapButton(find.widgetWithText(OutlinedButton, AppStrings.signOut));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.signOut));
  await settle();
  expect(find.text(AppStrings.signInTitle), findsOneWidget);
}
