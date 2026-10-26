/// Design tokens for layout. Widgets outside `core/theme/` use these instead
/// of numeric literals; `test/core/theme/theme_tokens_guard_test.dart`
/// enforces it.
///
/// The spacing scale is a 4-pt scale; the radii and sizes below that the Figma
/// file uses (input 5, button 10, button 50) were read from its frames.
library;

import 'package:flutter/painting.dart';

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

/// Sizes of the challenge screens, read from the Figma frames "Challenges - List"
/// and "Challenge - Detail".
abstract final class AppChallengeSizes {
  /// The cover of a challenge card.
  static const double cardCoverHeight = 132;

  /// The full-bleed cover at the top of the detail.
  static const double detailCoverHeight = 270;

  /// A small icon next to a line of text (dates, goal, participants).
  static const double metaIcon = 14;

  /// A tag on a cover (type, city): its icon.
  static const double tagIcon = 14;

  /// One tile of the countdown.
  static const double countdownTileHeight = 64;

  /// A medal's picture, in its tile.
  static const double medalImage = 44;

  /// A participant's placeholder avatar and its overlap.
  static const double avatar = 36;
  static const double avatarOverlap = 12;

  /// The most of the screen the reason above the action bar may take, so large
  /// text still leaves the challenge visible (the reason scrolls).
  static const double actionBarReasonShare = 0.3;

  /// The smallest height of the fixed action bar button.
  static const double actionButtonHeight = 50;

  /// The progress bar of a card in My Challenges.
  static const double progressBar = 8;
}

/// Sizes of the Profile tab (Figma frame `1:64`).
abstract final class AppProfileSizes {
  /// The round avatar with the user's initials.
  static const double avatar = 96;
}

/// Sizes of the Active tab (`docs/designs/003-active-tab.html`).
abstract final class AppActiveSizes {
  /// The circle behind the heart on the health gate, and the heart in it.
  static const double gateCircle = 88;
  static const double gateIcon = 40;

  /// The icon beside a tile's label, and the one in the Refresh data button.
  static const double tileIcon = 18;
}

/// The medal tiers' colors, from the Figma style "Medal colors". They tint a medal
/// that has no picture yet.
abstract final class AppMedalColors {
  static const Color bronze = Color(0xFFB07A4F);
  static const Color silver = Color(0xFFB9BCC2);
  static const Color gold = Color(0xFFDDB945);
}

/// The gradient behind a cover while its picture loads, or when there is none:
/// the Figma "Placeholder covers", one per challenge type (top, bottom).
abstract final class AppCoverColors {
  static const (Color, Color) run = (Color(0xFF4F6E1A), Color(0xFF0F1A0A));
  static const (Color, Color) swim = (Color(0xFF1E6E8C), Color(0xFF0A1822));
  static const (Color, Color) cycle = (Color(0xFF8C4E24), Color(0xFF1C0F0A));
}
