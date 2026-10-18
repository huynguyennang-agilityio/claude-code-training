/// Design tokens for layout. Widgets outside `core/theme/` use these instead
/// of numeric literals; `test/core/theme/theme_tokens_guard_test.dart`
/// enforces it.
///
/// The spacing scale is a 4-pt scale; the radii and sizes below that the Figma
/// file uses (input 5, button 10, button 50) were read from its frames.
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
  /// Input fields.
  static const double xs = 5;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  /// Primary buttons.
  static const double button = 10;

  /// Fully rounded ends (pills, avatars).
  static const double full = 999;
}

/// Fixed sizes for layout.
abstract final class AppSizes {
  /// The widest a form grows on a large screen, so fields don't stretch edge to edge.
  static const double formMaxWidth = 480;

  /// The smallest size of anything the user taps (Material and iOS
  /// accessibility guidelines).
  static const double minTapTarget = 48;

  /// Height of the bottom tab bar, without the bottom safe area.
  static const double tabBarHeight = 56;

  /// Height of a primary button.
  static const double buttonHeight = 50;
}
