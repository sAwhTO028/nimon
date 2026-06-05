import 'package:characters/characters.dart';
import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/features/mono/mono_content_model.dart';

String? _japaneseFromSentenceContent(Object? raw) {
  if (raw is! Map) return null;
  final o = <String, Object?>{
    for (var e in raw.entries) e.key.toString(): e.value
  };
  final t = o['japaneseText'];
  if (t is String) {
    final s = t.trim();
    return s.isEmpty ? null : s;
  }
  return null;
}

Map<String, Object?>? _asStringKeyMap(Object? raw) {
  if (raw is! Map) return null;
  return {for (var e in raw.entries) e.key.toString(): e.value};
}

/// Builds [MonoRubyToken] list from [japaneseText] and `furiganaSpans` JSON
/// (see [StorySentenceItem] / `story_creator_draft_storage` — `start`/`end` UTF-16, `reading`).
/// Returns empty when there are no usable spans (caller keeps [plainText] fallback).
List<MonoRubyToken> rubyTokensFromPublishedSentenceContent(
  String japaneseText,
  Object? contentMap,
) {
  final o = _asStringKeyMap(contentMap);
  if (o == null) return const [];
  final raw = o['furiganaSpans'];
  if (raw is! List || raw.isEmpty) return const [];

  final jp = japaneseText;
  if (jp.isEmpty) return const [];

  final spans = <({int start, int end, String reading})>[];
  for (final x in raw) {
    if (x is! Map) continue;
    final m = <String, Object?>{
      for (var e in x.entries) e.key.toString(): e.value
    };
    final st = m['start'];
    final en = m['end'];
    final rd = m['reading'];
    if (st is! int || en is! int) continue;
    if (st < 0 || en <= st || en > jp.length) continue;
    if (rd is! String) continue;
    final r = rd.trim();
    if (r.isEmpty) continue;
    spans.add((start: st, end: en, reading: r));
  }
  if (spans.isEmpty) return const [];

  spans.sort((a, b) => a.start.compareTo(b.start));
  final out = <MonoRubyToken>[];
  var cursor = 0;
  for (final s in spans) {
    if (s.start < cursor) {
      continue;
    }
    if (cursor < s.start) {
      final gap = jp.substring(cursor, s.start);
      for (final ch in gap.characters) {
        out.add(MonoRubyToken(text: ch));
      }
    }
    out.add(
      MonoRubyToken(
        text: jp.substring(s.start, s.end),
        reading: s.reading,
      ),
    );
    cursor = s.end;
  }
  if (cursor < jp.length) {
    final tail = jp.substring(cursor);
    for (final ch in tail.characters) {
      out.add(MonoRubyToken(text: ch));
    }
  }
  return out;
}

/// Maps published sentence `content` JSON to [MonoExplanationLine].
///
/// Shape: `meanings: { en, my }` (see [LocalizedMeanings] / draft storage).
/// Optional fallbacks: `sourceMeaning` / `englishMeaning` string fields.
MonoExplanationLine? explanationFromPublishedSentenceContent(
    Object? contentMap) {
  final o = _asStringKeyMap(contentMap);
  if (o == null) return null;

  String? en;
  String? my;

  final meanings = o['meanings'];
  if (meanings is Map) {
    final mm = <String, Object?>{
      for (var e in meanings.entries) e.key.toString(): e.value
    };
    final eRaw = mm['en'];
    final mRaw = mm['my'];
    if (eRaw is String) en = eRaw.trim().isEmpty ? null : eRaw.trim();
    if (mRaw is String) my = mRaw.trim().isEmpty ? null : mRaw.trim();
  }

  final es = o['englishMeaning'];
  if (en == null && es is String) {
    final t = es.trim();
    if (t.isNotEmpty) en = t;
  }
  final ss = o['sourceMeaning'];
  if (my == null && ss is String) {
    final t = ss.trim();
    if (t.isNotEmpty) my = t;
  }

  if ((en == null || en.isEmpty) && (my == null || my.isEmpty)) {
    return null;
  }
  return MonoExplanationLine(en: en, my: my);
}

/// All sentence lines joined for legacy [bodyText] / [effectiveBodyText].
String plainBodyFromPublishedCore(Object? contentRoot) {
  if (contentRoot is! Map) {
    return '';
  }
  final c = <String, Object?>{
    for (var e in contentRoot.entries) e.key.toString(): e.value
  };
  final core = c['core'];
  if (core is! Map) return '';
  final coreM = <String, Object?>{
    for (var e in core.entries) e.key.toString(): e.value
  };
  final sents = coreM['sentences'];
  if (sents is! List) return '';
  final lines = <String>[];
  for (final x in sents) {
    if (x is! Map) continue;
    final row = <String, Object?>{
      for (var e in x.entries) e.key.toString(): e.value
    };
    final cont = row['content'];
    final jp = _japaneseFromSentenceContent(cont);
    if (jp != null) lines.add(jp);
  }
  return lines.join('\n\n');
}

/// One page, one line per sentence; tokens empty → plain [MonoSentenceLine].
/// Reads `learningLanguage` from published content root when present.
String? learningLanguageFromPublishedRoot(Object? contentRoot) {
  if (contentRoot is! Map) return null;
  final c = <String, Object?>{
    for (var e in contentRoot.entries) e.key.toString(): e.value,
  };
  final direct = c['learningLanguage'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim().toLowerCase();
  }
  final basics = c['basics'];
  if (basics is Map) {
    final bm = <String, Object?>{
      for (var e in basics.entries) e.key.toString(): e.value,
    };
    final b = bm['learningLanguage'];
    if (b is String && b.trim().isNotEmpty) {
      return b.trim().toLowerCase();
    }
  }
  return null;
}

MonoContent? buildMonoContentFromPublishedCore(
  String id,
  String? title,
  Object? contentRoot, {
  String? learningLanguage,
}) {
  final effectiveLearning =
      learningLanguage ?? learningLanguageFromPublishedRoot(contentRoot);
  final showRuby = isJapaneseLearningWireCode(effectiveLearning);
  if (contentRoot is! Map) {
    return null;
  }
  final c = <String, Object?>{
    for (var e in contentRoot.entries) e.key.toString(): e.value
  };
  final core = c['core'];
  if (core is! Map) {
    return null;
  }
  final coreM = <String, Object?>{
    for (var e in core.entries) e.key.toString(): e.value
  };
  final sents = coreM['sentences'];
  if (sents is! List || sents.isEmpty) {
    return null;
  }
  final lines = <MonoSentenceLine>[];
  for (final x in sents) {
    if (x is! Map) continue;
    final row = <String, Object?>{
      for (var e in x.entries) e.key.toString(): e.value
    };
    final cont = row['content'];
    final jp = _japaneseFromSentenceContent(cont) ?? '';
    if (jp.isEmpty) continue;

    final tokens = showRuby
        ? rubyTokensFromPublishedSentenceContent(jp, cont)
        : const <MonoRubyToken>[];
    final explanation = explanationFromPublishedSentenceContent(cont);

    lines.add(
      MonoSentenceLine(
        tokens: tokens,
        plainText: jp,
        explanation: explanation,
      ),
    );
  }
  if (lines.isEmpty) {
    return null;
  }
  return MonoContent(
    id: id,
    title: (title ?? '').trim().isEmpty ? null : title?.trim(),
    pages: [
      MonoContentPage(
        pageId: 'p0',
        lines: lines,
      ),
    ],
  );
}
