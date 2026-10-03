import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A message strip above content, announced to screen readers.
///
/// Use [isError] for failures and leave it false for neutral notices.
class AppBanner extends StatelessWidget {
  /// Creates a banner.
  const AppBanner({
    required this.message,
    super.key,
    this.isError = false,
    this.icon,
    this.action,
  });

  /// Text to show.
  final String message;

  /// Whether to style the banner as an error.
  final bool isError;

  /// Leading icon; defaults to an error or info icon.
  final IconData? icon;

  /// Optional trailing action, usually a text button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Icon(
                icon ?? (isError ? Icons.error_outline : Icons.info_outline),
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: foreground),
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
