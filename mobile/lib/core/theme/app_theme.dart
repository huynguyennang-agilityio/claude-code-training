import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The app theme, taken from the Figma file "StrideQuest" (Colors section and
/// text styles). Figma only defines a dark theme, so there is no light one.
///
/// Screens read colors and text styles from `Theme.of(context)`; they never
/// name a color or a font.
abstract final class AppTheme {
  static const _darkest = Color(0xFF0F0F0F);
  static const _dark = Color(0xFF202020);
  static const _default = Color(0xFF303030);
  static const _light = Color(0xFF404040);
  static const _lime = Color(0xFFD0EC60);
  static const _white = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFA1A1A2);
  static const _textDisabled = Color(0xFF5F5E60);
  static const _error = Color(0xFFE54D4F);

  // Figma has no banner colors. These are ours, chosen so text on a banner
  // keeps a contrast of at least 4.5 (the accessibility guideline): a dark red
  // tint with a light red text for errors, a neutral surface for notices.
  static const _errorContainer = Color(0xFF3B1C1D);
  static const _onErrorContainer = Color(0xFFFFB4B5);

  static const _fontFamily = 'Inter';

  static const _colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _lime,
    onPrimary: _darkest,
    secondary: _lime,
    onSecondary: _darkest,
    error: _error,
    onError: _white,
    errorContainer: _errorContainer,
    onErrorContainer: _onErrorContainer,
    secondaryContainer: _default,
    onSecondaryContainer: _white,
    surface: _darkest,
    onSurface: _white,
    onSurfaceVariant: _textSecondary,
    surfaceContainerLowest: _darkest,
    surfaceContainerLow: _dark,
    surfaceContainer: _dark,
    surfaceContainerHigh: _default,
    surfaceContainerHighest: _light,
    outline: _default,
    outlineVariant: _default,
  );

  /// Inter at [size] and [weight]. The font is a variable font, so the weight
  /// is also set on its `wght` axis; `fontWeight` alone is not enough.
  static TextStyle _inter(double size, FontWeight weight) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
  );

  /// The Figma text styles, mapped to the Material roles that screens use.
  static final _textTheme = TextTheme(
    displaySmall: _inter(32, FontWeight.w700),
    headlineMedium: _inter(24, FontWeight.w700),
    titleLarge: _inter(18, FontWeight.w600),
    titleMedium: _inter(16, FontWeight.w600),
    bodyLarge: _inter(14, FontWeight.w400),
    bodyMedium: _inter(13, FontWeight.w400),
    bodySmall: _inter(13, FontWeight.w400),
    labelLarge: _inter(16, FontWeight.w600),
    labelMedium: _inter(13, FontWeight.w500),
    labelSmall: _inter(13, FontWeight.w600),
  ).apply(bodyColor: _white, displayColor: _white);

  static ThemeData get dark {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      borderSide: const BorderSide(color: _default),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: _darkest,
      fontFamily: _fontFamily,
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkest,
        foregroundColor: _white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: _textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lime,
          foregroundColor: _darkest,
          disabledBackgroundColor: _default,
          disabledForegroundColor: _textDisabled,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: _textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lime,
          textStyle: _textTheme.labelSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _dark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        hintStyle: _textTheme.bodyMedium?.copyWith(color: _textDisabled),
        labelStyle: _textTheme.bodyMedium?.copyWith(color: _textSecondary),
        floatingLabelStyle: _textTheme.bodyMedium?.copyWith(
          color: _textSecondary,
        ),
        errorStyle: _textTheme.bodyMedium?.copyWith(color: _error),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: _lime),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: _error),
        ),
      ),
    );
  }
}
