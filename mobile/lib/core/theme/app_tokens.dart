/// Design tokens for layout. Widgets outside `core/theme/` use these instead
/// of numeric literals; `test/core/theme/theme_tokens_guard_test.dart`
/// enforces it.
///
/// There is no design file yet, so the values are a starting 4-pt scale.
/// Replace them, not their names, when a design exists.
library;

/// Spacing scale in logical pixels, for padding, margins and gaps.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radius scale in logical pixels.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  /// Fully rounded ends (pills, avatars).
  static const double full = 999;
}

/// Fixed sizes for layout.
abstract final class AppSizes {
  /// The widest a form grows on a large screen, so fields don't stretch edge to edge.
  static const double formMaxWidth = 480;
}
