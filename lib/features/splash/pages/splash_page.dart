import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_error_view.dart';
import '../controllers/splash_controller.dart';

/// First screen: restores the session, then moves on.
class SplashPage extends StatelessWidget {
  /// Creates the page.
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<SplashController>(
          id: SplashController.stateId,
          builder: (controller) {
            if (controller.status == ViewStatus.error) {
              return AppErrorView(
                message: controller.errorMessage ?? AppStrings.failureUnknown,
                onRetry: controller.start,
              );
            }
            return const _SplashContent();
          },
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.task_alt,
              size: AppSizes.stateIcon,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.appName, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: AppStrings.loading,
            child: const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
