import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_state_view.dart';

/// Shown when navigation targets a route that does not exist.
class NotFoundPage extends StatelessWidget {
  /// Creates the page.
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppStateView(
          icon: Icons.explore_off_outlined,
          title: AppStrings.pageNotFoundTitle,
          message: AppStrings.pageNotFoundMessage,
          action: AppButton(
            label: AppStrings.goHome,
            onPressed: () => Get.offAllNamed<void>(RouteNames.splash),
          ),
        ),
      ),
    );
  }
}
