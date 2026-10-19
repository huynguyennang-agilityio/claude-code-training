import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/config/api_mode.dart';
import 'package:stridequest/core/config/app_config.dart';

void main() {
  group('resolveApiMode', () {
    test('a debug build with mock uses the fakes', () {
      expect(resolveApiMode('mock', isDebug: true), ApiMode.mock);
      expect(resolveApiMode(' MOCK ', isDebug: true), ApiMode.mock);
    });

    test('a profile or release build never uses the fakes', () {
      expect(resolveApiMode('mock', isDebug: false), ApiMode.real);
    });

    test('an empty or unknown value is real', () {
      for (final raw in ['', 'real', 'fake', 'mocks']) {
        expect(resolveApiMode(raw, isDebug: true), ApiMode.real, reason: raw);
      }
    });
  });

  test('without API_MODE the app uses the real API', () {
    expect(AppConfig.apiMode, ApiMode.real);
  });
}
