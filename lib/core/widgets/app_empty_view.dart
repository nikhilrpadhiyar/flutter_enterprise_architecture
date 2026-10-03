import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_state_view.dart';

/// Shown when a successful load returns nothing.
class AppEmptyView extends StatelessWidget {
  /// Creates an empty view.
  const AppEmptyView({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  /// Heading.
  final String title;

  /// Explanation.
  final String message;

  /// Illustrative icon.
  final IconData icon;

  /// Label of the optional action button.
  final String? actionLabel;

  /// Action callback; the button is shown only when both this and
  /// [actionLabel] are set.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return AppStateView(
      icon: icon,
      title: title,
      message: message,
      action: label == null || onAction == null
          ? null
          : AppButton(label: label, onPressed: onAction),
    );
  }
}
