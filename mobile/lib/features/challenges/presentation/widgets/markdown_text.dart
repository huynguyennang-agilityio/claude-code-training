import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Renders the small part of Markdown a challenge's text uses: paragraphs,
/// `-` or `*` bullet lists, `#` headings, and `**bold**` / `*italic*`.
///
/// It draws text only. Anything else, HTML tags included, shows as the literal
/// characters, and a link shows only its text, so a challenge's description
/// cannot inject markup or send the user somewhere.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    final blocks = _blocks(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _build(blocks[i], base),
        ],
      ],
    );
  }

  Widget _build(_Block block, TextStyle base) {
    switch (block.kind) {
      case _Kind.heading:
        return Text.rich(
          TextSpan(children: spans(block.text, base)),
          style: base.copyWith(fontWeight: FontWeight.w600),
        );
      case _Kind.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: base),
            Expanded(
              child: Text.rich(TextSpan(children: spans(block.text, base))),
            ),
          ],
        );
      case _Kind.paragraph:
        return Text.rich(
          TextSpan(children: spans(block.text, base)),
          style: base,
        );
    }
  }

  /// Splits [source] into blocks: blank lines separate paragraphs, and every
  /// bullet or heading line is a block of its own.
  static List<_Block> _blocks(String source) {
    final blocks = <_Block>[];
    final paragraph = <String>[];
    void flush() {
      if (paragraph.isNotEmpty) {
        blocks.add(_Block(_Kind.paragraph, paragraph.join(' ')));
        paragraph.clear();
      }
    }

    for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flush();
        blocks.add(_Block(_Kind.bullet, line.substring(2).trim()));
      } else if (line.startsWith('#')) {
        flush();
        blocks.add(
          _Block(_Kind.heading, line.replaceFirst(RegExp(r'^#+\s*'), '')),
        );
      } else {
        paragraph.add(line);
      }
    }
    flush();
    return blocks;
  }

  /// Inline spans of [text]: `**bold**`, `*italic*` and `[label](url)` (the
  /// label only).
  @visibleForTesting
  static List<InlineSpan> spans(String text, TextStyle base) {
    final withoutLinks = text.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      (match) => match[1]!,
    );
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    final result = <InlineSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(withoutLinks)) {
      if (match.start > last) {
        result.add(TextSpan(text: withoutLinks.substring(last, match.start)));
      }
      result.add(
        match[1] != null
            ? TextSpan(
                text: match[1],
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : TextSpan(
                text: match[2],
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
      );
      last = match.end;
    }
    if (last < withoutLinks.length) {
      result.add(TextSpan(text: withoutLinks.substring(last)));
    }
    return result;
  }
}

enum _Kind { paragraph, bullet, heading }

class _Block {
  const _Block(this.kind, this.text);

  final _Kind kind;
  final String text;
}
