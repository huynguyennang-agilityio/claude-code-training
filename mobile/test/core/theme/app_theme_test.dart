import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/core/theme/app_tokens.dart';

void main() {
  final theme = AppTheme.dark;

  test('is a dark Material 3 theme with the Lime accent', () {
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xFFD0EC60));
    expect(theme.colorScheme.onPrimary, const Color(0xFF0F0F0F));
    expect(theme.colorScheme.error, const Color(0xFFE54D4F));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0F0F));
  });

  test('surface and text colors follow the Figma colors', () {
    final scheme = theme.colorScheme;
    expect(scheme.surface, const Color(0xFF0F0F0F));
    expect(scheme.surfaceContainer, const Color(0xFF202020));
    expect(scheme.outline, const Color(0xFF303030));
    expect(scheme.onSurface, const Color(0xFFFFFFFF));
    expect(scheme.onSurfaceVariant, const Color(0xFFA1A1A2));
  });

  group('text styles are Inter at the Figma size and weight', () {
    final textTheme = theme.textTheme;
    final cases = <String, (TextStyle?, double, FontWeight)>{
      'display (32 Bold)': (textTheme.displaySmall, 32, FontWeight.w700),
      'heading (24 Bold)': (textTheme.headlineMedium, 24, FontWeight.w700),
      'title (18 Semi Bold)': (textTheme.titleLarge, 18, FontWeight.w600),
      'button (16 Semi Bold)': (textTheme.labelLarge, 16, FontWeight.w600),
      'body large (14 Regular)': (textTheme.bodyLarge, 14, FontWeight.w400),
      'body (13 Regular)': (textTheme.bodyMedium, 13, FontWeight.w400),
      'body medium (13 Medium)': (textTheme.labelMedium, 13, FontWeight.w500),
      'body semi bold (13 Semi Bold)': (
        textTheme.labelSmall,
        13,
        FontWeight.w600,
      ),
    };
    cases.forEach((name, spec) {
      test(name, () {
        final (style, size, weight) = spec;
        expect(style?.fontFamily, 'Inter');
        expect(style?.fontSize, size);
        expect(style?.fontWeight, weight);
        expect(style?.fontVariations, [
          FontVariation.weight(weight.value.toDouble()),
        ]);
      });
    });
  });

  test('filled buttons are Lime, 50 high with radius 10', () {
    final style = theme.filledButtonTheme.style!;
    expect(style.backgroundColor?.resolve({}), const Color(0xFFD0EC60));
    expect(style.foregroundColor?.resolve({}), const Color(0xFF0F0F0F));
    expect(
      style.minimumSize?.resolve({}),
      const Size.fromHeight(AppSizes.buttonHeight),
    );
    final shape = style.shape?.resolve({}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(AppRadius.button));
  });

  test('input fields have a dark fill and a 1 px border with radius 5', () {
    final input = theme.inputDecorationTheme;
    expect(input.filled, isTrue);
    expect(input.fillColor, const Color(0xFF202020));
    final border = input.enabledBorder! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(AppRadius.xs));
    expect(border.borderSide.color, const Color(0xFF303030));
    expect(
      (input.errorBorder! as OutlineInputBorder).borderSide.color,
      const Color(0xFFE54D4F),
    );
  });
}
