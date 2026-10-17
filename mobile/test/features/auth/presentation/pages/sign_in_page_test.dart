import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('shows the placeholder on $size at text x$textScale', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const SignInPage(),
          size: size,
          textScale: textScale,
        );

        expectNoLayoutException(tester);
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Sign in to continue.'), findsOneWidget);
        await expectAccessible(tester);
      });
    }
  }
}
