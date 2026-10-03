import '../theme/app_sizes.dart';

/// Width class of the current layout.
enum ScreenSize {
  /// Phones, under 600 dp.
  compact,

  /// Small tablets, 600 to 1023 dp.
  medium,

  /// Large tablets, desktop and web, 1024 dp and up.
  expanded;

  /// Classifies a layout [width].
  static ScreenSize fromWidth(double width) {
    if (width < AppSizes.compactBreakpoint) return ScreenSize.compact;
    if (width < AppSizes.expandedBreakpoint) return ScreenSize.medium;
    return ScreenSize.expanded;
  }
}
