import 'package:nimon/features/mono/mono_content_model.dart';

String? _japaneseFromSentenceContent(Object? raw) {
  if (raw is! Map) return null;
  final o = <String, Object?>{for (var e in raw.entries) e.key.toString(): e.value};
  final t = o['japaneseText'];
  if (t is String) {
    final s = t.trim();
    return s.isEmpty ? null : s;
  }
  return null;
}

/// All sentence lines joined for legacy [bodyText] / [effectiveBodyText].
String plainBodyFromPublishedCore(Object? contentRoot) {
  if (contentRoot is! Map) {
    return '';
  }
  final c = <String, Object?>{for (var e in contentRoot.entries) e.key.toString(): e.value};
  final core = c['core'];
  if (core is! Map) return '';
  final coreM = <String, Object?>{for (var e in core.entries) e.key.toString(): e.value};
  final sents = coreM['sentences'];
  if (sents is! List) return '';
  final lines = <String>[];
  for (final x in sents) {
    if (x is! Map) continue;
    final row = <String, Object?>{for (var e in x.entries) e.key.toString(): e.value};
    final cont = row['content'];
    final jp = _japaneseFromSentenceContent(cont);
    if (jp != null) lines.add(jp);
  }
  return lines.join('\n\n');
}

/// One page, one line per sentence; tokens empty → plain [MonoSentenceLine].
MonoContent? buildMonoContentFromPublishedCore(
  String id,
  String? title,
  Object? contentRoot,
) {
  if (contentRoot is! Map) {
    return null;
  }
  final c = <String, Object?>{for (var e in contentRoot.entries) e.key.toString(): e.value};
  final core = c['core'];
  if (core is! Map) {
    return null;
  }
  final coreM = <String, Object?>{for (var e in core.entries) e.key.toString(): e.value};
  final sents = coreM['sentences'];
  if (sents is! List || sents.isEmpty) {
    return null;
  }
  final lines = <MonoSentenceLine>[];
  for (final x in sents) {
    if (x is! Map) continue;
    final row = <String, Object?>{for (var e in x.entries) e.key.toString(): e.value};
    final cont = row['content'];
    final jp = _japaneseFromSentenceContent(cont) ?? '';
    if (jp.isEmpty) continue;
    lines.add(
      MonoSentenceLine(
        tokens: const [],
        plainText: jp,
        explanation: null,
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
