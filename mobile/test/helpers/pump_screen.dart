import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/theme/app_theme.dart';

/// A small phone (iPhone SE class), in logical pixels.
const smallPhone = Size(375, 667);

/// A large phone (Pro Max class), in logical pixels.
const largePhone = Size(430, 932);

/// Pumps [screen] under `AppTheme.light` on a screen of [size], with text
/// scaled by [textScale] (the OS font-size setting), and settles it.
///
/// Pass `settle: false` for a screen with an endless animation, such as the
/// loading state's `CircularProgressIndicator`: `pumpAndSettle` would time out.
///
/// The size and scale are undone when the test ends. A layout overflow throws
/// during the pump; call `expectNoLayoutException` to fail on one that was
/// caught while settling.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = smallPhone,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Fails if building or laying out the screen threw, for example with a
/// `RenderFlex overflowed` error.
void expectNoLayoutException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
