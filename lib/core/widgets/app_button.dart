import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// Primary action.
  filled,

  /// Secondary action.
  outlined,

  /// Low emphasis action.
  text,
}

/// The app's standard button.
///
/// Shows a spinner and ignores taps while [isLoading], and keeps the minimum
/// touch target size from the theme.
class AppButton extends StatelessWidget {
  /// Creates a button. A null [onPressed] disables it.
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.filled,
    this.isLoading = false,
    this.icon,
    this.expand = false,
  });

  /// Button text.
  final String label;

  /// Tap callback, or null to disable.
  final VoidCallback? onPressed;

  /// Emphasis level.
  final AppButtonVariant variant;

  /// Whether an operation is in progress.
  final bool isLoading;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button fills the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final content = isLoading ? const _Spinner() : _Label(label, icon);
    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.text => TextButton(onPressed: callback, child: content),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.icon);

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppSizes.icon),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.loading,
      child: const SizedBox(
        width: AppSizes.buttonSpinner,
        height: AppSizes.buttonSpinner,
        child: CircularProgressIndicator(strokeWidth: AppSizes.spinnerStroke),
      ),
    );
  }
}
