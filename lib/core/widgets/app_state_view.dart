import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';

/// Shared layout of the empty and error views: icon, title, message, action.
class AppStateView extends StatelessWidget {
  /// Creates a state view.
  const AppStateView({
    required this.icon,
    required this.message,
    super.key,
    this.title,
    this.action,
    this.iconColor,
  });

  /// Illustrative icon.
  final IconData icon;

  /// Optional heading.
  final String? title;

  /// Explanation.
  final String message;

  /// Optional action, usually a button.
  final Widget? action;

  /// Icon colour; defaults to the outline colour.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.stateMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: AppSizes.stateIcon,
                  color: iconColor ?? theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (title != null) ...<Widget>[
                Text(
                  title!,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
