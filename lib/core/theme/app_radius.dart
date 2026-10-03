import 'package:flutter/widgets.dart';

/// Corner radius scale.
abstract final class AppRadius {
  /// Medium radius for inputs and buttons.
  static const double md = 12;

  /// Large radius for cards and sheets.
  static const double lg = 20;

  /// Medium radius as a [BorderRadius].
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));

  /// Large radius as a [BorderRadius].
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}
