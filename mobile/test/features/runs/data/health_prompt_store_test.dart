import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/runs/data/datasources/health_prompt_store.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late SecureHealthPromptStore store;
  final values = <String, String>{};

  setUp(() {
    values.clear();
    storage = _MockStorage();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      values[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((i) async => values[i.namedArguments[#key] as String]);
    store = SecureHealthPromptStore(storage);
  });

  test('nothing stored reads as null', () async {
    expect(await store.explainerShownAt(), isNull);
  });

  test('the time round-trips through the stored UTC string', () async {
    final at = DateTime.utc(2026, 10, 19, 12, 30);

    await store.recordExplainerShown(at);

    expect(values['health_explainer_shown_at'], '2026-10-19T12:30:00.000Z');
    // A new store over the same storage is what an app restart gives.
    final shown = await SecureHealthPromptStore(storage).explainerShownAt();
    expect(shown!.isAtSameMomentAs(at), isTrue);
    expect(shown.isUtc, isFalse);
  });

  test('a read error is null', () async {
    when(() => storage.read(key: any(named: 'key'))).thenThrow(Exception());
    expect(await store.explainerShownAt(), isNull);
  });

  test('a write error is ignored', () async {
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(Exception());
    await store.recordExplainerShown(DateTime.utc(2026));
  });

  test('the asked count is untouched', () async {
    await store.recordAsked();
    await store.recordExplainerShown(DateTime.utc(2026, 10, 19));

    expect(await store.askedCount(), 1);
    expect(values['health_permission_asked'], '1');
  });
}
