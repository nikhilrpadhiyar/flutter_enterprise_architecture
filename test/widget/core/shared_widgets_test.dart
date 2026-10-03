import 'package:flutter/material.dart';
import 'package:flutter_enterprise_architecture/core/constants/app_strings.dart';
import 'package:flutter_enterprise_architecture/core/theme/app_sizes.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_button.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_card.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_dialog.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_empty_view.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_error_view.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_loader.dart';
import 'package:flutter_enterprise_architecture/core/widgets/app_text_field.dart';
import 'package:flutter_enterprise_architecture/core/widgets/stale_data_banner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('AppButton', () {
    testWidgets('invokes the callback when tapped', (tester) async {
      var taps = 0;
      await pumpApp(tester, AppButton(label: 'Save', onPressed: () => taps++));
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('is inert and shows a spinner while loading', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        AppButton(label: 'Save', isLoading: true, onPressed: () => taps++),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('is disabled without a callback', (tester) async {
      await pumpApp(tester, const AppButton(label: 'Save', onPressed: null));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('renders every variant', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await pumpApp(
          tester,
          AppButton(label: 'Go', variant: variant, onPressed: () {}),
        );
        expect(find.text('Go'), findsOneWidget);
      }
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('meets the minimum touch target', (tester) async {
      await pumpApp(tester, AppButton(label: 'Go', onPressed: () {}));
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    });

    testWidgets('expands to the available width', (tester) async {
      await pumpApp(
        tester,
        AppButton(label: 'Go', expand: true, onPressed: () {}),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).width,
        TestScreens.phone.width,
      );
    });

    testWidgets('stays usable at large text scale', (tester) async {
      await pumpApp(
        tester,
        AppButton(label: 'Create task', icon: Icons.add, onPressed: () {}),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Create task'), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('reports changes and shows the error text', (tester) async {
      String? changed;
      await pumpApp(
        tester,
        AppTextField(
          label: 'Email',
          errorText: 'Enter a valid email address.',
          onChanged: (value) => changed = value,
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      expect(changed, 'ada');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('password field toggles visibility', (tester) async {
      await pumpApp(
        tester,
        const AppTextField(label: 'Password', obscureText: true),
      );
      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField)).obscureText;

      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip(AppStrings.showPassword));
      await tester.pump();
      expect(obscured(), isFalse);
      await tester.tap(find.byTooltip(AppStrings.hidePassword));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('does not accept input when disabled', (tester) async {
      await pumpApp(tester, const AppTextField(label: 'Email', enabled: false));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('AppCard', () {
    testWidgets('is tappable when given a callback', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        AppCard(onTap: () => taps++, child: const Text('Project')),
      );
      await tester.tap(find.text('Project'));
      expect(taps, 1);
    });

    testWidgets('is static without a callback', (tester) async {
      await pumpApp(tester, const AppCard(child: Text('Project')));
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('state views', () {
    testWidgets('AppLoader announces loading and shows a message', (
      tester,
    ) async {
      await pumpApp(tester, const AppLoader(message: 'Loading tasks'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading tasks'), findsOneWidget);
    });

    testWidgets('AppErrorView shows the message and retries', (tester) async {
      var retries = 0;
      await pumpApp(
        tester,
        AppErrorView(message: 'Something broke', onRetry: () => retries++),
      );
      expect(find.text('Something broke'), findsOneWidget);
      await tester.tap(find.text(AppStrings.tryAgain));
      expect(retries, 1);
    });

    testWidgets('AppErrorView hides retry without a callback', (tester) async {
      await pumpApp(tester, const AppErrorView(message: 'Offline'));
      expect(find.text(AppStrings.tryAgain), findsNothing);
    });

    testWidgets('AppEmptyView shows its action only when complete', (
      tester,
    ) async {
      var taps = 0;
      await pumpApp(
        tester,
        AppEmptyView(
          title: 'No tasks',
          message: 'Create your first task.',
          actionLabel: 'Create task',
          onAction: () => taps++,
        ),
      );
      expect(find.text('No tasks'), findsOneWidget);
      await tester.tap(find.text('Create task'));
      expect(taps, 1);

      await pumpApp(
        tester,
        const AppEmptyView(title: 'No tasks', message: 'Nothing here.'),
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('state views fit a small screen at large text scale', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AppErrorView(message: 'Something went wrong. ' * 4, onRetry: () {}),
        size: const Size(320, 480),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('StaleDataBanner shows the saved data notice', (tester) async {
      await pumpApp(tester, const StaleDataBanner());
      expect(find.text(AppStrings.staleData), findsOneWidget);
    });
  });

  group('AppDialog.confirm', () {
    Future<void> openDialog(WidgetTester tester, void Function(bool) onResult) {
      return pumpApp(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'Delete',
            onPressed: () async => onResult(
              await AppDialog.confirm(
                context,
                title: 'Delete task',
                message: 'This cannot be undone.',
                isDestructive: true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('returns true when confirmed', (tester) async {
      bool? result;
      await openDialog(tester, (value) => result = value);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete task'), findsOneWidget);
      await tester.tap(find.text(AppStrings.confirm));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result;
      await openDialog(tester, (value) => result = value);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('returns false when dismissed', (tester) async {
      bool? result;
      await openDialog(tester, (value) => result = value);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  testWidgets('widgets render in the dark theme', (tester) async {
    await pumpApp(
      tester,
      Column(
        children: <Widget>[
          AppButton(label: 'Go', onPressed: () {}),
          const StaleDataBanner(),
          const AppCard(child: Text('Card')),
        ],
      ),
      themeMode: ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
