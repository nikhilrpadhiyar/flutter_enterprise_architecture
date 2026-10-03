import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../utils/screen_size.dart';

/// One top-level destination of the app shell.
@immutable
class AppDestination {
  /// Creates a destination.
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  /// Text label.
  final String label;

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected.
  final IconData selectedIcon;

  /// Route opened by the destination.
  final String route;
}

/// Page frame with navigation that adapts to the screen width.
///
/// Phones get a bottom bar, tablets a rail, and large screens an extended
/// rail. Page content is centred and limited to a readable width.
class AppShellScaffold extends StatelessWidget {
  /// Creates the shell.
  const AppShellScaffold({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  /// Navigation targets.
  final List<AppDestination> destinations;

  /// Index of the selected destination.
  final int currentIndex;

  /// Called when the user picks a destination.
  final ValueChanged<int> onDestinationSelected;

  /// Page content.
  final Widget body;

  /// Title shown in the app bar.
  final String? title;

  /// App bar actions.
  final List<Widget>? actions;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final size = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: body,
      ),
    );
    final appBar = AppBar(
      title: title == null ? null : Text(title!),
      actions: actions,
    );
    if (size == ScreenSize.compact) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(child: content),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: <Widget>[
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Row(
          children: <Widget>[
            NavigationRail(
              extended: size == ScreenSize.expanded,
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: size == ScreenSize.expanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
