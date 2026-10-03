import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/login_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Sign in screen.
class LoginPage extends StatelessWidget {
  /// Creates the page.
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: AppStrings.signInTitle,
      subtitle: AppStrings.signInSubtitle,
      child: GetBuilder<LoginController>(
        id: LoginController.formId,
        builder: (controller) => AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (controller.showSessionExpiredNotice) ...<Widget>[
                const AppBanner(message: AppStrings.failureAuthentication),
                const SizedBox(height: AppSpacing.md),
              ],
              if (controller.errorMessage != null) ...<Widget>[
                AppBanner(message: controller.errorMessage!, isError: true),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: AppStrings.emailLabel,
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                enabled: !controller.isSubmitting,
                errorText: controller.fieldErrors['email'],
                onChanged: controller.onEmailChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.passwordLabel,
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                enabled: !controller.isSubmitting,
                errorText: controller.fieldErrors['password'],
                onChanged: controller.onPasswordChanged,
                onSubmitted: (_) => controller.submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: AppStrings.signIn,
                expand: true,
                isLoading: controller.isSubmitting,
                onPressed: controller.submit,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: AppStrings.goToRegister,
                variant: AppButtonVariant.text,
                onPressed: controller.isSubmitting
                    ? null
                    : controller.openRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
