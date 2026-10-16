import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Raw style values that must come from the theme or `app_tokens.dart`.
final _forbidden = <String, RegExp>{
  'hex color': RegExp(r'\bColor\(\s*0x'),
  'color constructor': RegExp(r'\bColor\.from(ARGB|RGBO)\('),
  'Colors constant': RegExp(r'\bColors\.\w+'),
  'numeric EdgeInsets': RegExp(r'\bEdgeInsets\w*\.\w+\([^)]*?\b\d'),
  'numeric SizedBox size': RegExp(r'\bSizedBox\([^)]*?\b(width|height):\s*\d'),
  'numeric radius': RegExp(r'\b(BorderRadius|Radius)\.circular\(\s*\d'),
  'numeric fontSize': RegExp(r'\bfontSize:\s*\d'),
};

final _generated = RegExp(r'\.(g|freezed|config)\.dart$');

/// Whether the guard checks [path], a `/`-separated path under `lib/`.
bool isGuarded(String path) =>
    path.endsWith('.dart') &&
    !path.startsWith('lib/core/theme/') &&
    !_generated.hasMatch(path);

/// Returns `line: rule` for each raw style value in [source].
List<String> findViolations(String source) {
  final code = _stripComments(source);
  return [
    for (final MapEntry(key: rule, value: pattern) in _forbidden.entries)
      for (final match in pattern.allMatches(code))
        '${_lineOf(code, match.start)}: $rule',
  ];
}

/// Blanks out comments but keeps newlines, so line numbers stay correct.
String _stripComments(String source) => source
    .replaceAllMapped(
      RegExp(r'/\*.*?\*/', dotAll: true),
      (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
    )
    .replaceAll(RegExp(r'//[^\n]*'), '');

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  group('findViolations', () {
    const forbidden = {
      'hex color': 'Container(color: Color(0xFF112233))',
      'color constructor': 'Color.fromARGB(255, 0, 0, 0)',
      'Colors constant': 'Icon(Icons.add, color: Colors.red)',
      'numeric EdgeInsets': 'EdgeInsets.symmetric(\n  horizontal: 16,\n)',
      'numeric SizedBox size': 'SizedBox(height: 8)',
      'numeric radius': 'BorderRadius.circular(12)',
      'numeric fontSize': 'TextStyle(fontSize: 14)',
    };

    for (final MapEntry(key: rule, value: source) in forbidden.entries) {
      test('flags $rule', () {
        expect(findViolations(source), ['1: $rule']);
      });
    }

    test('reports the line of the violation', () {
      expect(findViolations('const a = 1;\n\nfinal b = SizedBox(width: 4);'), [
        '3: numeric SizedBox size',
      ]);
    });

    test('allows theme values and tokens', () {
      const source = '''
Padding(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: SizedBox(
    height: AppSpacing.xs,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
)
EdgeInsets.zero
Text('Run', style: Theme.of(context).textTheme.titleLarge)
''';
      expect(findViolations(source), isEmpty);
    });

    test('ignores comments', () {
      const source = '''
// Not Colors.red: use colorScheme.
/* Was EdgeInsets.all(16)
   and fontSize: 14. */
final x = 1;
''';
      expect(findViolations(source), isEmpty);
    });
  });

  group('isGuarded', () {
    test('checks feature and core files', () {
      expect(
        isGuarded('lib/features/home/presentation/pages/home_page.dart'),
        isTrue,
      );
      expect(isGuarded('lib/core/router/app_router.dart'), isTrue);
    });

    test('skips the theme and generated files', () {
      expect(isGuarded('lib/core/theme/app_tokens.dart'), isFalse);
      expect(
        isGuarded('lib/features/auth/data/models/token_pair_model.g.dart'),
        isFalse,
      );
      expect(
        isGuarded(
          'lib/features/auth/data/models/token_pair_model.freezed.dart',
        ),
        isFalse,
      );
      expect(isGuarded('lib/core/di/injection.config.dart'), isFalse);
    });
  });

  test('lib/ uses theme values and tokens instead of raw style values', () {
    final violations = [
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (isGuarded(file.path.replaceAll(r'\', '/')))
          for (final violation in findViolations(file.readAsStringSync()))
            '${file.path}:$violation',
    ];

    expect(
      violations,
      isEmpty,
      reason:
          'Use Theme.of(context).colorScheme / textTheme and AppSpacing / '
          'AppRadius from lib/core/theme/app_tokens.dart.',
    );
  });
}
