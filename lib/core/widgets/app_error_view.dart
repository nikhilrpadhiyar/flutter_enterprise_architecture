import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import 'app_button.dart';
import 'app_state_view.dart';

/// Shown when loading fails. Offers a retry when [onRetry] is given.
class AppErrorView extends StatelessWidget {
  /// Creates an error view.
  const AppErrorView({required this.message, super.key, this.onRetry});

  /// User-friendly description of the failure.
  final String message;

  /// Retry callback, or null to hide the button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      icon: Icons.error_outline,
      iconColor: Theme.of(context).colorScheme.error,
      message: message,
      action: onRetry == null
          ? null
          : AppButton(
              label: AppStrings.tryAgain,
              icon: Icons.refresh,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
    );
  }
}
