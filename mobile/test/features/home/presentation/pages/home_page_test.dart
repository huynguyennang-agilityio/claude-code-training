import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/home/presentation/pages/home_page.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('shows the title and tagline on $size at text x$textScale', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const HomePage(),
          size: size,
          textScale: textScale,
        );

        expectNoLayoutException(tester);
        expect(find.text('StrideQuest'), findsOneWidget);
        expect(find.text('Every run is a quest.'), findsOneWidget);
        await expectAccessible(tester);
      });
    }
  }
}
