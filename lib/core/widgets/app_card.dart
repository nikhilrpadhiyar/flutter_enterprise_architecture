import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The app's standard card surface.
///
/// When [onTap] is set the whole card is tappable with a ripple and exposed
/// to assistive technology as a button.
class AppCard extends StatelessWidget {
  /// Creates a card.
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.semanticLabel,
  });

  /// Card content.
  final Widget child;

  /// Tap callback, or null for a static card.
  final VoidCallback? onTap;

  /// Space around the content.
  final EdgeInsetsGeometry padding;

  /// Label announced by screen readers for tappable cards.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Semantics(
              button: true,
              label: semanticLabel,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.lgAll,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
  }
}
