import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:stridequest/core/theme/app_theme.dart';

/// Golden tests use CI goldens only: text is drawn as solid blocks, so they
/// catch layout, spacing, size and color changes, not fonts. Edge
/// anti-aliasing still differs between operating systems, so the baselines
/// are made on an Apple Silicon Mac and CI compares them on macOS (the
/// `goldens` job in `.github/workflows/mobile-ci.yml`), never on Linux.
Future<void> testExecutable(Future<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: AppTheme.dark,
      platformGoldensConfig: const PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
