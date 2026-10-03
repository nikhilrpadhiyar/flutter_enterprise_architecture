import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_destinations.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/state/view_status.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/stale_data_banner.dart';
import '../../../domain/entities/app_theme_mode.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/user_role.dart';
import '../../settings/controllers/theme_controller.dart';
import '../controllers/profile_controller.dart';

/// The signed-in user's profile, appearance setting and sign out.
class ProfilePage extends StatelessWidget {
  /// Creates the page.
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      destinations: AppDestinations.all,
      currentIndex: AppDestinations.indexOf(RouteNames.profile),
      onDestinationSelected: AppDestinations.open,
      title: AppStrings.profileTitle,
      body: GetBuilder<ProfileController>(
        id: ProfileController.profileId,
        builder: (controller) => _Body(controller),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.controller);

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    if (user == null) {
      return controller.status == ViewStatus.error
          ? AppErrorView(
              message: controller.errorMessage ?? AppStrings.failureUnknown,
              onRetry: controller.load,
            )
          : const AppLoader();
    }
    final errors = controller.fieldErrors;
    final busy = controller.isSaving;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (controller.isStale) ...<Widget>[
                const StaleDataBanner(),
                const SizedBox(height: AppSpacing.md),
              ],
              _Identity(user),
              const SizedBox(height: AppSpacing.lg),
              if (controller.formError != null) ...<Widget>[
                AppBanner(message: controller.formError!, isError: true),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: AppStrings.nameLabel,
                controller: controller.nameController,
                errorText: errors['name'],
                enabled: !busy,
                textInputAction: TextInputAction.next,
                onChanged: (_) => controller.onFieldChanged('name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.phoneLabel,
                controller: controller.phoneController,
                errorText: errors['phone'],
                enabled: !busy,
                keyboardType: TextInputType.phone,
                onChanged: (_) => controller.onFieldChanged('phone'),
                onSubmitted: (_) => controller.save(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: AppStrings.saveChanges,
                expand: true,
                isLoading: busy,
                onPressed: controller.save,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _ThemeSelector(),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: AppStrings.signOut,
                icon: Icons.logout,
                variant: AppButtonVariant.outlined,
                expand: true,
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: AppStrings.signOutTitle,
      message: controller.signOutMessage,
      confirmLabel: AppStrings.signOut,
      isDestructive: true,
    );
    if (confirmed) await controller.signOut();
  }
}

class _Identity extends StatelessWidget {
  const _Identity(this.user);

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().substring(0, 1).toUpperCase();
    return Column(
      children: <Widget>[
        ExcludeSemantics(
          child: CircleAvatar(
            radius: AppSizes.avatar,
            child: Text(initial, style: theme.textTheme.headlineMedium),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(user.name, style: theme.textTheme.titleLarge),
        Text(user.email, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${AppStrings.roleLabel}: ${_roleName(user.role)}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _roleName(UserRole role) => switch (role) {
    UserRole.admin => AppStrings.roleAdmin,
    UserRole.manager => AppStrings.roleManager,
    UserRole.member => AppStrings.roleMember,
  };
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<ThemeController>(
      id: ThemeController.themeId,
      builder: (controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              AppStrings.appearance,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<AppThemeMode>>[
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                label: Text(AppStrings.themeSystem),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                label: Text(AppStrings.themeLight),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                label: Text(AppStrings.themeDark),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: <AppThemeMode>{controller.mode},
            onSelectionChanged: (selection) =>
                controller.choose(selection.first),
          ),
        ],
      ),
    );
  }
}
