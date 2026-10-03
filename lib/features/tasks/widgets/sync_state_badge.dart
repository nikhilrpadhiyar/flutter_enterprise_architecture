import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/sync_state.dart';

/// Shows whether a task is confirmed by the server. Renders nothing for
/// synced tasks.
class SyncStateBadge extends StatelessWidget {
  /// Creates a badge for [state].
  const SyncStateBadge(this.state, {super.key});

  /// The task's sync state.
  final SyncState state;

  @override
  Widget build(BuildContext context) {
    if (state == SyncState.synced) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final failed = state == SyncState.failed;
    final color = failed ? scheme.error : scheme.outline;
    final label = failed ? AppStrings.notSaved : AppStrings.waitingToSync;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          failed ? Icons.error_outline : Icons.cloud_upload_outlined,
          size: AppSpacing.md,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
