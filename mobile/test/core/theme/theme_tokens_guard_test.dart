import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Raw style values that must come from the theme or `app_tokens.dart`.
///
/// The guard reads source text, not types: it misses a raw value that reaches
/// a widget through a variable (`final gap = 8.0; EdgeInsets.all(gap)`).
final _rules = <_Rule>[
  _Rule('hex color', RegExp(r'\b\w*Color\(\s*0[xX]')),
  _Rule('color constructor', RegExp(r'\bColor\.from(ARGB|RGBO)?\(')),
  _Rule(
    'Colors constant',
    RegExp(r'\b(Cupertino)?Colors\.(?!transparent\b)\w+'),
  ),
  _Rule(
    'numeric EdgeInsets',
    RegExp(r'\bEdgeInsets\w*\.\w+\('),
    (code, match) => _hasNumber(_argumentsAt(code, match.end)),
  ),
  _Rule(
    'numeric SizedBox size',
    RegExp(r'\bSizedBox(\.\w+)?\('),
    (code, match) => _splitTopLevel(_argumentsAt(code, match.end)).any(
      (argument) => switch (_sizeArgument.firstMatch(argument)) {
        final size? => _hasNumber(size[1]!),
        null => false,
      },
    ),
  ),
  _Rule(
    'numeric radius',
    RegExp(r'\b(BorderRadius\w*|Radius)\.(circular|elliptical)\('),
    (code, match) => _hasNumber(_argumentsAt(code, match.end)),
  ),
  _Rule(
    'numeric fontSize',
    RegExp(r'\bfontSize:'),
    (code, match) =>
        _hasNumber(_splitTopLevel(code.substring(match.end)).first),
  ),
];

final _sizeArgument = RegExp(
  r'^\s*(?:width|height|dimension|size)\s*:(.*)$',
  dotAll: true,
);

/// A numeric literal, not a digit inside an identifier such as `x2`.
final _number = RegExp(r'(?<![\w$.])\d');

final _generated = RegExp(r'\.(g|freezed|config)\.dart$');

class _Rule {
  const _Rule(this.name, this.pattern, [this.check]);

  final String name;

  /// Finds a candidate in source whose comments and strings are blanked.
  final RegExp pattern;

  /// Whether the candidate at [Match] is a violation; `null` means it always is.
  final bool Function(String code, Match match)? check;

  bool violates(String code, Match match) => check?.call(code, match) ?? true;
}

/// Whether the guard checks [path], a `/`-separated path under `lib/`.
bool isGuarded(String path) =>
    path.endsWith('.dart') &&
    !path.startsWith('lib/core/theme/') &&
    !_generated.hasMatch(path);

/// Returns `line: rule` for each raw style value in [source].
List<String> findViolations(String source) {
  final code = _blankCommentsAndStrings(source);
  return [
    for (final rule in _rules)
      for (final match in rule.pattern.allMatches(code))
        if (rule.violates(code, match))
          '${_lineOf(code, match.start)}: ${rule.name}',
  ];
}

bool _hasNumber(String code) => _number.hasMatch(code);

/// The text after an opening bracket at [start], up to its closing bracket.
String _argumentsAt(String code, int start) {
  var depth = 0;
  for (var i = start; i < code.length; i++) {
    if ('([{'.contains(code[i])) {
      depth++;
    } else if (')]}'.contains(code[i])) {
      if (depth == 0) return code.substring(start, i);
      depth--;
    }
  }
  return code.substring(start);
}

/// Splits [code] at its top-level commas, stopping at an unmatched closing
/// bracket.
List<String> _splitTopLevel(String code) {
  final parts = <String>[];
  var depth = 0;
  var from = 0;
  for (var i = 0; i < code.length; i++) {
    final char = code[i];
    if ('([{'.contains(char)) {
      depth++;
    } else if (')]}'.contains(char)) {
      if (depth == 0) return parts..add(code.substring(from, i));
      depth--;
    } else if (char == ',' && depth == 0) {
      parts.add(code.substring(from, i));
      from = i + 1;
    }
  }
  return parts..add(code.substring(from));
}

/// Replaces comments and string literals with spaces, keeping newlines so line
/// numbers stay correct. Code inside string interpolation is blanked too.
String _blankCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  void blankUntil(int end) {
    for (; i < end; i++) {
      out.write(source[i] == '\n' ? '\n' : ' ');
    }
  }

  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      blankUntil(end == -1 ? source.length : end);
    } else if (source.startsWith('/*', i)) {
      blankUntil(_blockCommentEnd(source, i));
    } else if (_isStringStart(source, i)) {
      blankUntil(_stringEnd(source, i));
    } else {
      out.write(source[i]);
      i++;
    }
  }
  return out.toString();
}

/// The end of the block comment at [start]. Dart block comments nest.
int _blockCommentEnd(String source, int start) {
  var depth = 0;
  var i = start;
  while (i < source.length) {
    if (source.startsWith('/*', i)) {
      depth++;
      i += 2;
    } else if (source.startsWith('*/', i)) {
      depth--;
      i += 2;
      if (depth == 0) return i;
    } else {
      i++;
    }
  }
  return source.length;
}

bool _isStringStart(String source, int i) {
  bool isQuote(int at) =>
      at < source.length && (source[at] == "'" || source[at] == '"');
  if (isQuote(i)) return true;
  return source[i] == 'r' &&
      isQuote(i + 1) &&
      (i == 0 || !RegExp(r'[\w$]').hasMatch(source[i - 1]));
}

/// The end of the string literal at [start]: single or triple quotes,
/// optionally raw.
int _stringEnd(String source, int start) {
  var i = start;
  final raw = source[i] == 'r';
  if (raw) i++;
  final quote = source[i];
  final close = source.startsWith(quote * 3, i) ? quote * 3 : quote;
  i += close.length;
  while (i < source.length) {
    if (!raw && source[i] == r'\') {
      i += 2;
    } else if (source.startsWith(close, i)) {
      return i + close.length;
    } else if (close.length == 1 && source[i] == '\n') {
      return i;
    } else {
      i++;
    }
  }
  return source.length;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  group('findViolations', () {
    const forbidden = [
      ('hex color', 'Container(color: Color(0xFF112233))'),
      ('hex color', 'MaterialColor(0xFF2196F3, {})'),
      ('color constructor', 'Color.fromARGB(255, 0, 0, 0)'),
      ('color constructor', 'Color.fromRGBO(0, 0, 0, 1)'),
      ('color constructor', 'Color.from(alpha: 1, red: 0, green: 0, blue: 0)'),
      ('Colors constant', 'Icon(Icons.add, color: Colors.red)'),
      ('Colors constant', 'CupertinoColors.systemRed'),
      ('numeric EdgeInsets', 'EdgeInsets.all(16)'),
      ('numeric EdgeInsets', 'const EdgeInsetsDirectional.only(start: 8)'),
      ('numeric EdgeInsets', 'const EdgeInsets.all(\n  16,\n)'),
      ('numeric EdgeInsets', 'EdgeInsets.only(left: f(x), top: 8)'),
      ('numeric EdgeInsets', 'EdgeInsets.all(AppSpacing.md * 2)'),
      ('numeric SizedBox size', 'SizedBox(height: 8)'),
      ('numeric SizedBox size', 'SizedBox(child: Text(a), height: 8)'),
      ('numeric SizedBox size', 'SizedBox.square(dimension: 8)'),
      ('numeric SizedBox size', 'SizedBox.fromSize(size: Size(8, 8))'),
      ('numeric radius', 'BorderRadius.circular(12)'),
      ('numeric radius', 'BorderRadius.all(Radius.circular(8))'),
      ('numeric radius', 'BorderRadiusDirectional.circular(8)'),
      ('numeric radius', 'Radius.elliptical(8, 4)'),
      ('numeric fontSize', 'TextStyle(fontSize: 14)'),
      ('numeric fontSize', 'TextStyle(fontSize: base + 2, height: h)'),
    ];

    for (final (rule, source) in forbidden) {
      test('flags $rule in ${source.replaceAll('\n', ' ')}', () {
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
      child: Text('a', maxLines: 2),
    ),
  ),
)
EdgeInsets.zero
SizedBox.shrink()
ColoredBox(color: Colors.transparent)
Text('Run', style: Theme.of(context).textTheme.titleLarge)
''';
      expect(findViolations(source), isEmpty);
    });

    test('ignores comments, including nested block comments', () {
      const source = '''
// Not Colors.red: use colorScheme.
/* Was EdgeInsets.all(16)
   /* and */ fontSize: 14. */
final x = 1;
''';
      expect(findViolations(source), isEmpty);
    });

    test('ignores style values inside strings', () {
      const source = '''
Text('Use Colors.red and EdgeInsets.all(16)');
Text("""it's fontSize: 14""");
''';
      expect(findViolations(source), isEmpty);
    });

    test('does not treat // or /* in a string as a comment', () {
      expect(
        findViolations("Text('https://x.io', style: TextStyle(fontSize: 14))"),
        ['1: numeric fontSize'],
      );
      expect(
        findViolations(
          "final g = 'lib/*';\nfinal p = EdgeInsets.all(16);\n/* c */",
        ),
        ['2: numeric EdgeInsets'],
      );
    });

    test(r'ends a raw string at its quote, not after a \', () {
      expect(findViolations(r"final p = r'a\'; final q = EdgeInsets.all(8);"), [
        '1: numeric EdgeInsets',
      ]);
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
