import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/register_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Registration screen.
class RegisterPage extends StatelessWidget {
  /// Creates the page.
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: AppStrings.registerTitle,
      subtitle: AppStrings.registerSubtitle,
      child: GetBuilder<RegisterController>(
        id: RegisterController.formId,
        builder: (controller) => AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (controller.errorMessage != null) ...<Widget>[
                AppBanner(message: controller.errorMessage!, isError: true),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: AppStrings.nameLabel,
                prefixIcon: Icons.person_outline,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.name],
                enabled: !controller.isSubmitting,
                errorText: controller.fieldErrors['name'],
                onChanged: controller.onNameChanged,
              ),
              const SizedBox(height: AppSpacing.md),
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
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                enabled: !controller.isSubmitting,
                errorText: controller.fieldErrors['password'],
                onChanged: controller.onPasswordChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.confirmPasswordLabel,
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.newPassword],
                enabled: !controller.isSubmitting,
                errorText: controller.fieldErrors['confirmPassword'],
                onChanged: controller.onConfirmPasswordChanged,
                onSubmitted: (_) => controller.submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: AppStrings.createAccount,
                expand: true,
                isLoading: controller.isSubmitting,
                onPressed: controller.submit,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: AppStrings.goToSignIn,
                variant: AppButtonVariant.text,
                onPressed: controller.isSubmitting
                    ? null
                    : controller.openSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
