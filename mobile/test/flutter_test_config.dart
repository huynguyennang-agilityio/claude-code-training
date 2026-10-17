import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:stridequest/core/theme/app_theme.dart';

/// Golden tests use CI goldens only: text is drawn as solid blocks, so the
/// images are identical on every operating system and need no per-platform
/// baselines. They catch layout, spacing, size and color changes, not fonts.
Future<void> testExecutable(Future<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: AppTheme.light,
      platformGoldensConfig: const PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
