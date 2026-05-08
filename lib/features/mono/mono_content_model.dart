/// Mono structured reading content models (V1+).
///
/// Data-first, lightweight: supports line-based reading, optional furigana, and
/// optional per-line explanations. UI can still fall back to plain text.

/// Ruby token for Japanese line rendering (furigana-ready).
///
/// Example:
/// - text: '図書館', reading: 'としょかん'
/// - text: 'で', reading: null
class MonoRubyToken {
  const MonoRubyToken({
    required this.text,
    this.reading,
  });

  final String text;

  /// Kana reading shown above [text] (furigana). Null = no ruby.
  final String? reading;
}

/// Optional explanation/support line for a single Japanese sentence line.
class MonoExplanationLine {
  const MonoExplanationLine({this.en, this.my});

  final String? en;
  final String? my;
}

/// One visible Japanese sentence line in the reader.
class MonoSentenceLine {
  const MonoSentenceLine({
    required this.tokens,
    required this.plainText,
    this.explanation,
  });

  final List<MonoRubyToken> tokens;

  /// Pre-joined Japanese string for fallback display / copy.
  final String plainText;

  final MonoExplanationLine? explanation;
}

/// One page of reading content (for fixed multi-page authoring).
class MonoContentPage {
  const MonoContentPage({
    required this.pageId,
    required this.lines,
  });

  final String pageId;
  final List<MonoSentenceLine> lines;
}

/// Structured Mono content (line-based, furigana/explanations optional).
class MonoContent {
  const MonoContent({
    required this.id,
    this.title,
    required this.pages,
  });

  final String id;
  final String? title;
  final List<MonoContentPage> pages;

  /// Best-effort plain text fallback for the current reader UI (V1).
  ///
  /// - Pages are separated by a blank line.
  /// - Lines are separated by '\n'.
  /// - If tokens are empty, we fall back to [MonoSentenceLine.plainText].
  String toPlainText() {
    final out = StringBuffer();
    for (int p = 0; p < pages.length; p++) {
      final page = pages[p];
      for (final line in page.lines) {
        final toks = line.tokens;
        if (toks.isNotEmpty) {
          out.writeln(toks.map((t) => t.text).join());
        } else {
          out.writeln(line.plainText);
        }
      }
      if (p != pages.length - 1) out.writeln();
    }
    return out.toString().trimRight();
  }
}
