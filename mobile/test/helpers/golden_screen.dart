import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';

import 'pump_screen.dart';

/// Golden-tests [screen] at both phone sizes and both text scales, in one
/// image `goldens/ci/<fileName>.png` next to the calling test.
///
/// Regenerate the baseline with `flutter test --update-goldens --tags golden`
/// and review the image diff in the merge request.
void goldenScreen(String description, String fileName, Widget screen) {
  goldenTest(
    description,
    fileName: fileName,
    tags: ['golden'],
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
