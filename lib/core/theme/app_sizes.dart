/// Fixed dimensions and responsive breakpoints.
abstract final class AppSizes {
  /// Minimum touch target edge, per Material accessibility guidance.
  static const double minTouchTarget = 48;

  /// Width below which the compact (phone) layout is used.
  static const double compactBreakpoint = 600;

  /// Width at and above which the expanded layout is used.
  static const double expandedBreakpoint = 1024;

  /// Maximum width of centred page content on large screens.
  static const double maxContentWidth = 1200;

  /// Width of the centred card on authentication pages.
  static const double authCardWidth = 420;

  /// Standard icon size.
  static const double icon = 24;

  /// Avatar diameter in lists.
  static const double avatar = 40;

  /// Diameter of the spinner shown inside buttons.
  static const double buttonSpinner = 20;

  /// Stroke width of small spinners.
  static const double spinnerStroke = 2;

  /// Size of illustrative icons on empty and error views.
  static const double stateIcon = 64;

  /// Maximum width of text blocks on state views.
  static const double stateMaxWidth = 360;

  /// Maximum width of forms such as the task and profile forms.
  static const double formMaxWidth = 630;

  /// Width of a compact dropdown placed beside others.
  static const double dropdownWidth = 200;

  /// Maximum width of a bottom sheet on wide screens.
  static const double sheetMaxWidth = 560;
}
