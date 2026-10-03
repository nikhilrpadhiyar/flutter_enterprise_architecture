import 'package:flutter/material.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/screen_size.dart';
import '../../../core/widgets/app_card.dart';

/// Shared frame of the authentication screens: a centred, scrollable column
/// that sits on a card on wider screens.
class AuthScaffold extends StatelessWidget {
  /// Creates the frame.
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  /// Heading.
  final String title;

  /// Text under the heading.
  final String subtitle;

  /// The form.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) !=
        ScreenSize.compact;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            Icons.task_alt,
            size: AppSizes.stateIcon,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.authCardWidth,
              ),
              child: isWide
                  ? AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: content,
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }
}
