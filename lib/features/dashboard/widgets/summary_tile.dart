import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// A headline number with a label, such as "12 Open tasks".
class SummaryTile extends StatelessWidget {
  /// Creates a tile. [color] tints the number (for example red for overdue).
  const SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
    this.color,
  });

  /// What the number counts.
  final String label;

  /// The number.
  final int value;

  /// Icon beside the label.
  final IconData icon;

  /// Colour of the number; defaults to the text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: AppSpacing.md,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$value',
                style: theme.textTheme.headlineMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
