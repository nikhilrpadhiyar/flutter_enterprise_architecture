import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import 'app_banner.dart';

/// Notice shown above data that was loaded from device storage because the
/// server could not be reached.
class StaleDataBanner extends StatelessWidget {
  /// Creates a banner.
  const StaleDataBanner({super.key, this.message = AppStrings.staleData});

  /// Banner text.
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppBanner(message: message, icon: Icons.cloud_off_outlined);
  }
}
