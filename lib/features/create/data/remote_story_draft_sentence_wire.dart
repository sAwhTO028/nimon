import 'package:nimon/features/create/data/dto/story_draft_dto.dart';

/// JSON encode/decode for [StorySentenceDto] used by [RemoteStoryDraftRepository]
/// PUT/GET — aligned with [StoryCreatorDraftStorage] sentence maps and P1 reader keys:
/// `japaneseText`, `furiganaSpans`, `meanings.en`, `meanings.my`.

int? _intFromJson(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  return null;
}

String? _optionalTrimmedString(Object? v) {
  if (v == null) return null;
  if (v is String) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

Map<String, Object?> localizedMeaningsDtoToWireJson(LocalizedMeaningsDto m) {
  return {
    'en': m.en,
    'my': m.my,
    'byLanguage': Map<String, String>.from(m.byLanguage),
  };
}

LocalizedMeaningsDto? localizedMeaningsDtoFromWireJson(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  final m = <String, Object?>{
    for (final e in raw.entries) e.key.toString(): e.value,
  };
  final enStr = _optionalTrimmedString(m['en']);
  final myStr = _optionalTrimmedString(m['my']);
  final blRaw = m['byLanguage'];
  final byLang = <String, String>{};
  if (blRaw is Map) {
    for (final e in blRaw.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v == null) continue;
      byLang[k] = v is String ? v : v.toString();
    }
  }
  final dto = LocalizedMeaningsDto(
    en: enStr,
    my: myStr,
    byLanguage: byLang,
  );
  final hasContent = (dto.en != null && dto.en!.trim().isNotEmpty) ||
      (dto.my != null && dto.my!.trim().isNotEmpty) ||
      dto.byLanguage.isNotEmpty;
  return hasContent ? dto : null;
}

Map<String, Object?> contentProvenanceDtoToWireJson(ContentProvenanceDto p) {
  return {
    'sourceMode': p.sourceMode,
    'lastReviewedByCreator': p.lastReviewedByCreator,
  };
}

ContentProvenanceDto? contentProvenanceDtoFromWireJson(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  final m = <String, Object?>{
    for (final e in raw.entries) e.key.toString(): e.value,
  };
  final sm = m['sourceMode'];
  final lr = m['lastReviewedByCreator'];
  if (sm == null && lr == null) return null;
  return ContentProvenanceDto(
    sourceMode: sm is String ? sm : (sm?.toString() ?? 'manual'),
    lastReviewedByCreator: lr is bool ? lr : false,
  );
}

List<FuriganaSpanDto> furiganaSpansFromWireJson(Object? raw) {
  if (raw is! List) return const [];
  final out = <FuriganaSpanDto>[];
  for (final x in raw) {
    if (x is! Map) continue;
    final o = <String, Object?>{
      for (final e in x.entries) e.key.toString(): e.value,
    };
    final st = _intFromJson(o['start']);
    final en = _intFromJson(o['end']);
    final rd = o['reading'];
    if (st == null || en == null || rd is! String) continue;
    out.add(
      FuriganaSpanDto(start: st, end: en, reading: rd),
    );
  }
  return out;
}

/// Wire JSON for one sentence row (matches local `_toJsonSentence` shape).
Map<String, Object?> storySentenceDtoToWireJson(StorySentenceDto s) {
  return {
    'id': s.id,
    'storyId': s.storyId,
    'orderIndex': s.orderIndex,
    'japaneseText': s.japaneseText,
    'reading': s.reading,
    'furiganaSpans': [
      for (final f in s.furiganaSpans)
        <String, Object?>{
          'start': f.start,
          'end': f.end,
          'reading': f.reading,
        },
    ],
    'meanings':
        s.meanings == null ? null : localizedMeaningsDtoToWireJson(s.meanings!),
    'audioStartMs': s.audioStartMs,
    'audioEndMs': s.audioEndMs,
    'provenance': s.provenance == null
        ? null
        : contentProvenanceDtoToWireJson(s.provenance!),
  };
}

StorySentenceDto storySentenceDtoFromWireJson(Map<String, Object?> m) {
  return StorySentenceDto(
    id: (m['id'] as String?) ?? '',
    storyId: (m['storyId'] as String?) ?? '',
    orderIndex: _intFromJson(m['orderIndex']) ?? 0,
    japaneseText: (m['japaneseText'] as String?) ?? '',
    reading: m['reading'] as String?,
    furiganaSpans: furiganaSpansFromWireJson(m['furiganaSpans']),
    meanings: localizedMeaningsDtoFromWireJson(m['meanings']),
    audioStartMs: _intFromJson(m['audioStartMs']),
    audioEndMs: _intFromJson(m['audioEndMs']),
    provenance: contentProvenanceDtoFromWireJson(m['provenance']),
  );
}
