import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/remote_story_draft_sentence_wire.dart';

/// JSON encode/decode for vocabulary, grammar, quiz, and story audio DTOs used by
/// [RemoteStoryDraftRepository] PUT/GET — aligned with [StoryCreatorDraftStorage]
/// layer maps (`glosses`, `examplePairs`, `meanings`, `provenance`, etc.).

int? _intFromJson(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  return null;
}

int _intFromJsonWithDefault(Object? v, int defaultValue) {
  return _intFromJson(v) ?? defaultValue;
}

List<VocabularyExamplePairDto> _vocabExamplePairsFromWire(Object? raw) {
  if (raw is! List) return const [];
  final out = <VocabularyExamplePairDto>[];
  for (final x in raw) {
    if (x is! Map) continue;
    final o = <String, Object?>{
      for (final e in x.entries) e.key.toString(): e.value,
    };
    final src = o['source'];
    final eng = o['english'];
    final sourceStr = src is String ? src : src?.toString() ?? '';
    final englishStr = eng is String ? eng : eng?.toString() ?? '';
    out.add(VocabularyExamplePairDto(source: sourceStr, english: englishStr));
  }
  return out;
}

List<GrammarExampleDto> _grammarExamplesFromWire(Object? raw) {
  if (raw is! List) return const [];
  final out = <GrammarExampleDto>[];
  for (final x in raw) {
    if (x is! Map) continue;
    final o = <String, Object?>{
      for (final e in x.entries) e.key.toString(): e.value,
    };
    final jp = o['japanese'];
    final japaneseStr = jp is String ? jp : jp?.toString() ?? '';
    out.add(
      GrammarExampleDto(
        japanese: japaneseStr,
        meanings: localizedMeaningsDtoFromWireJson(o['meanings']),
      ),
    );
  }
  return out;
}

List<String> _quizOptionsFromWire(Object? raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final x in raw) {
    if (x == null) continue;
    out.add(x is String ? x : x.toString());
  }
  return out;
}

/// Wire JSON for one vocabulary/kanji entry (matches local `_toJsonVocabLayer` row).
Map<String, Object?> vocabularyKanjiEntryDtoToWireJson(
    VocabularyKanjiEntryDto e) {
  return {
    'id': e.id,
    'termJapanese': e.termJapanese,
    'type': e.type,
    'reading': e.reading,
    'glosses':
        e.glosses == null ? null : localizedMeaningsDtoToWireJson(e.glosses!),
    'exampleSentence': e.exampleSentence,
    'exampleMeanings': e.exampleMeanings == null
        ? null
        : localizedMeaningsDtoToWireJson(e.exampleMeanings!),
    'examplePairs': [
      for (final p in e.examplePairs)
        <String, Object?>{
          'source': p.source,
          'english': p.english,
        },
    ],
    'provenance': e.provenance == null
        ? null
        : contentProvenanceDtoToWireJson(e.provenance!),
  };
}

VocabularyKanjiEntryDto vocabularyKanjiEntryDtoFromWireJson(
    Map<String, Object?> m) {
  return VocabularyKanjiEntryDto(
    id: (m['id'] as String?) ?? '',
    termJapanese: (m['termJapanese'] as String?) ?? '',
    type: (m['type'] as String?) ?? 'vocabulary',
    reading: m['reading'] as String?,
    glosses: localizedMeaningsDtoFromWireJson(m['glosses']),
    exampleSentence: m['exampleSentence'] as String?,
    exampleMeanings: localizedMeaningsDtoFromWireJson(m['exampleMeanings']),
    examplePairs: _vocabExamplePairsFromWire(m['examplePairs']),
    provenance: contentProvenanceDtoFromWireJson(m['provenance']),
  );
}

Map<String, Object?> grammarEntryDtoToWireJson(GrammarEntryDto e) {
  return {
    'id': e.id,
    'headline': e.headline,
    'form': e.form,
    'meanings':
        e.meanings == null ? null : localizedMeaningsDtoToWireJson(e.meanings!),
    'usage': e.usage == null ? null : localizedMeaningsDtoToWireJson(e.usage!),
    'examples': [
      for (final x in e.examples)
        <String, Object?>{
          'japanese': x.japanese,
          'meanings': x.meanings == null
              ? null
              : localizedMeaningsDtoToWireJson(x.meanings!),
        },
    ],
    'mistakeWrong': e.mistakeWrong,
    'mistakeCorrect': e.mistakeCorrect,
    'relatedNote': e.relatedNote == null
        ? null
        : localizedMeaningsDtoToWireJson(e.relatedNote!),
    'provenance': e.provenance == null
        ? null
        : contentProvenanceDtoToWireJson(e.provenance!),
  };
}

GrammarEntryDto grammarEntryDtoFromWireJson(Map<String, Object?> m) {
  return GrammarEntryDto(
    id: (m['id'] as String?) ?? '',
    headline: (m['headline'] as String?) ?? '',
    form: m['form'] as String?,
    meanings: localizedMeaningsDtoFromWireJson(m['meanings']),
    usage: localizedMeaningsDtoFromWireJson(m['usage']),
    examples: _grammarExamplesFromWire(m['examples']),
    mistakeWrong: m['mistakeWrong'] as String?,
    mistakeCorrect: m['mistakeCorrect'] as String?,
    relatedNote: localizedMeaningsDtoFromWireJson(m['relatedNote']),
    provenance: contentProvenanceDtoFromWireJson(m['provenance']),
  );
}

Map<String, Object?> quizEntryDtoToWireJson(QuizEntryDto e) {
  return {
    'id': e.id,
    'category': e.category,
    'prompt': e.prompt,
    'options': e.options,
    'correctIndex': e.correctIndex,
    'explanations': e.explanations == null
        ? null
        : localizedMeaningsDtoToWireJson(e.explanations!),
    'sourceNote': e.sourceNote,
    'provenance': e.provenance == null
        ? null
        : contentProvenanceDtoToWireJson(e.provenance!),
  };
}

QuizEntryDto quizEntryDtoFromWireJson(Map<String, Object?> m) {
  return QuizEntryDto(
    id: (m['id'] as String?) ?? '',
    category: (m['category'] as String?) ?? '',
    prompt: (m['prompt'] as String?) ?? '',
    options: _quizOptionsFromWire(m['options']),
    correctIndex: _intFromJsonWithDefault(m['correctIndex'], 0),
    explanations: localizedMeaningsDtoFromWireJson(m['explanations']),
    sourceNote: m['sourceNote'] as String?,
    provenance: contentProvenanceDtoFromWireJson(m['provenance']),
  );
}

/// Optional alternate keys for device paths (tolerant decode only).
String? _audioLocalPathFromWire(Map<String, Object?> m) {
  String? pick(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  return pick(m['localPath']) ??
      pick(m['localFilePath']) ??
      pick(m['localUri']);
}

Map<String, Object?> storyAudioDtoToWireJson(StoryAudioDto a) {
  return {
    'id': a.id,
    'sourceUrl': a.sourceUrl,
    'localFileName': a.localFileName,
    'localPath': a.localPath,
    'localSizeBytes': a.localSizeBytes,
    'localExtension': a.localExtension,
    'displayName': a.displayName,
    'durationSeconds': a.durationSeconds,
    'provenance': a.provenance == null
        ? null
        : contentProvenanceDtoToWireJson(a.provenance!),
  };
}

StoryAudioDto storyAudioDtoFromWireJson(Map<String, Object?> m) {
  return StoryAudioDto(
    id: (m['id'] as String?) ?? '',
    sourceUrl: m['sourceUrl'] as String?,
    localFileName: m['localFileName'] as String?,
    localPath: _audioLocalPathFromWire(m),
    localSizeBytes: _intFromJson(m['localSizeBytes']),
    localExtension: m['localExtension'] as String?,
    displayName: m['displayName'] as String?,
    durationSeconds: _intFromJson(m['durationSeconds']),
    provenance: contentProvenanceDtoFromWireJson(m['provenance']),
  );
}
