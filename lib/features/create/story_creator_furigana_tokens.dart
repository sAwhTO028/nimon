import 'package:characters/characters.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// One visible segment for “manage furigana” mode (UTF-16 indices match [String] / [FuriganaSpan]).
class StoryFuriganaToken {
  const StoryFuriganaToken({
    required this.start,
    required this.end,
    required this.text,
  });

  /// Half-open [start], [end) in UTF-16 code units.
  final int start;
  final int end;
  final String text;

  bool get isKanjiTappable => _containsKanji(text);
}

bool storyTextContainsKanji(String s) =>
    RegExp(r'[\u4E00-\u9FFF\u3005\u3006\u3007]').hasMatch(s);

bool _containsKanji(String s) => storyTextContainsKanji(s);

enum _ScriptGroup { kanji, kana, other }

_ScriptGroup _groupForGrapheme(String ch) {
  if (RegExp(r'^[\u4E00-\u9FFF\u3005\u3006\u3007]$').hasMatch(ch)) {
    return _ScriptGroup.kanji;
  }
  if (RegExp(r'^[\u3040-\u309F\u30A0-\u30FF]$').hasMatch(ch)) {
    return _ScriptGroup.kana;
  }
  return _ScriptGroup.other;
}

/// Splits [text] into contiguous script runs (kanji / kana / other) for tap targets.
///
/// Kanji detection for tap eligibility uses [storyTextContainsKanji] on each segment.
///
/// Never throws: on failure returns an empty list so UI can show a safe fallback.
List<StoryFuriganaToken> splitStoryTextIntoFuriganaTokens(String text) {
  try {
    return _splitStoryTextIntoFuriganaTokensImpl(text);
  } catch (_) {
    return const [];
  }
}

List<StoryFuriganaToken> _splitStoryTextIntoFuriganaTokensImpl(String text) {
  if (text.isEmpty) return const [];

  final out = <StoryFuriganaToken>[];
  var groupStart = 0;
  var cu = 0;
  _ScriptGroup? current;

  void flushThrough(int endExclusive) {
    if (endExclusive <= groupStart) return;
    out.add(StoryFuriganaToken(
      start: groupStart,
      end: endExclusive,
      text: text.substring(groupStart, endExclusive),
    ));
    groupStart = endExclusive;
  }

  for (final ch in text.characters) {
    final g = _groupForGrapheme(ch);
    final len = ch.length;
    if (current == null) {
      current = g;
    } else if (g != current) {
      flushThrough(cu);
      current = g;
    }
    cu += len;
  }
  flushThrough(cu);
  return out;
}

/// Exact [start]/[end] match only — duplicate surface forms at different offsets stay distinct.
String? readingForExactTokenRange(
  List<FuriganaSpan> spans,
  int start,
  int end,
) {
  for (final f in spans) {
    if (!f.isValid) continue;
    if (f.start == start && f.end == end) return f.reading;
  }
  return null;
}

/// Draft [StorySentenceItem] whose [StorySentenceItem.japaneseText] matches
/// [exampleLine] after trimming both sides, or null.
///
/// Use the returned row’s [StorySentenceItem.japaneseText] as the display string
/// for furigana (span indices are defined on that string, not on arbitrary edits).
StorySentenceItem? storySentenceMatchingTrimmedExampleLine(
  String exampleLine,
  List<StorySentenceItem> sentences,
) {
  final want = exampleLine.trim();
  if (want.isEmpty) return null;
  for (final s in sentences) {
    if (s.japaneseText.trim() == want) return s;
  }
  return null;
}
