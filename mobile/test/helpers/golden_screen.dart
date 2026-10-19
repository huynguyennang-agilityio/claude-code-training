import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';

import 'pump_screen.dart';

/// Golden-tests [screen] at both phone sizes and both text scales, in one
/// image `goldens/ci/<fileName>.png` next to the calling test.
///
/// Pass `settle: false` for a state with an endless animation.
///
/// Regenerate the baseline with `flutter test --update-goldens --tags golden`
/// and review the image diff in the pull request.
void goldenScreen(
  String description,
  String fileName,
  Widget screen, {
  bool settle = true,
}) {
  goldenTest(
    description,
    fileName: fileName,
    tags: ['golden'],
    // An endless animation, such as a progress indicator, never settles.
    pumpBeforeTest: settle ? onlyPumpAndSettle : pumpOnce,
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final size in [smallPhone, largePhone])
          for (final textScale in [1.0, 2.0])
            GoldenTestScenario.builder(
              name:
                  '${size.width.toInt()}×${size.height.toInt()}, text ×$textScale',
              constraints: BoxConstraints.tight(size),
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: screen,
              ),
            ),
      ],
    ),
  );
}
