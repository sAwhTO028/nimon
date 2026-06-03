import 'package:nimon/features/create/creator_completion_rules.dart'
    show syncModuleWorkflowWithContent;
import 'package:nimon/features/create/story_basics_category_options.dart';
import 'package:nimon/features/create/import/nimon_import_enums.dart';
import 'package:nimon/features/create/import/nimon_import_meta.dart';
import 'package:nimon/features/create/import/nimon_import_payload.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:uuid/uuid.dart';

// -----------------------------------------------------------------------------
// Maps validated AI import JSON → [CreatorStoryV1] (never [CreatorStoryV1.fromJson]).
//
// Caller must run [validateNimonImportPayload] first. Does not persist or call APIs.
// -----------------------------------------------------------------------------

/// Thrown when import JSON cannot be mapped despite passing validation.
class NimonImportMappingException implements Exception {
  NimonImportMappingException(this.message, {this.path});

  final String message;
  final String? path;

  @override
  String toString() {
    final p = path == null || path!.isEmpty ? '' : ' ($path)';
    return 'NimonImportMappingException$p: $message';
  }
}

const _uuid = Uuid();

/// Default provenance for rows imported from AI JSON.
const ContentProvenance kNimonImportContentProvenance = ContentProvenance(
  sourceMode: ContentSourceMode.aiDraft,
  lastReviewedByCreator: false,
);

/// Maps [payload] into a new local [CreatorStoryV1] draft (new [Uuid] story id).
CreatorStoryV1 mapNimonImportPayloadToCreatorStoryV1(
  NimonImportRawPayload payload, {
  required String ownerId,
}) {
  final meta = payload.meta;
  final core = payload.core;
  if (meta == null) {
    throw NimonImportMappingException(
      'Missing nimonImportMeta.',
      path: 'nimonImportMeta',
    );
  }
  if (core == null) {
    throw NimonImportMappingException('Missing core.', path: 'core');
  }
  if (!meta.hasRecognizedImportKind) {
    throw NimonImportMappingException(
      'Unsupported publishKind.',
      path: 'nimonImportMeta.publishKind',
    );
  }

  final storyId = _uuid.v4();
  final now = DateTime.now();
  final owner = ownerId.trim();

  final sentences = _mapSentences(core, storyId);
  if (sentences.isEmpty) {
    throw NimonImportMappingException(
      'No mappable sentences in core.',
      path: 'core.sentences',
    );
  }

  final basics = _mapBasics(
    core: core,
    storyId: storyId,
    ownerId: owner,
    meta: meta,
    payload: payload,
    now: now,
  );

  final isFullLearn = meta.importKind == NimonImportKind.fullLearn;

  final vocabularyKanji = isFullLearn
      ? VocabularyKanjiLayer(entries: _mapVocabularyEntries(payload.learn))
      : const VocabularyKanjiLayer();

  final grammar = isFullLearn
      ? GrammarLayer(entries: _mapGrammarEntries(payload.learn))
      : const GrammarLayer();

  final quiz = isFullLearn
      ? QuizLayer(entries: _mapQuizEntries(payload.learn))
      : const QuizLayer();

  final audio = isFullLearn
      ? AudioLayer(storyAudio: _mapStoryAudio(payload.learn))
      : const AudioLayer();

  final modules = {
    for (final m in LearnModuleId.values) m: LearnModuleTaskStatus.notStarted,
  };

  var draft = CreatorStoryV1(
    basics: basics,
    sentences: sentences,
    vocabularyKanji: vocabularyKanji,
    grammar: grammar,
    quiz: quiz,
    audio: audio,
    publishState: StoryPublishState.draft,
    moduleWorkflowStatuses: modules,
    publishedMonoId: null,
    hasUnpublishedCoreChanges: null,
  );

  return syncModuleWorkflowWithContent(draft);
}

StoryBasics _mapBasics({
  required Map<String, dynamic> core,
  required String storyId,
  required String ownerId,
  required NimonImportMeta meta,
  required NimonImportRawPayload payload,
  required DateTime now,
}) {
  return StoryBasics(
    storyId: storyId,
    title: _optStr(core['title']),
    category: normalizeImportedStoryBasicsCategory(_optStr(core['category'])),
    level: _optStr(core['level']),
    description: _optStr(core['description']),
    promptSourceNote: _buildImportPromptSourceNote(meta, payload),
    targetDurationBandKey: _optStrOrNull(
      core['targetDurationBandKey'] ?? core['target_duration_band_key'],
    ),
    coverImageUrl: _optStrOrNull(
      core['coverImageUrl'] ?? core['cover_image_url'],
    ),
    contentLocale: meta.contentCommunity.contentLocaleWireCode,
    learningLanguage: meta.learningLanguage.preferencesWireCode,
    creatorOwnerId: ownerId,
    createdAt: now,
    updatedAt: now,
  );
}

String _buildImportPromptSourceNote(
  NimonImportMeta meta,
  NimonImportRawPayload payload,
) {
  final lines = <String>[
    '[nimon-import]',
    'schemaVersion=${meta.schemaVersion ?? ''}',
    if ((meta.generatorVersion ?? '').trim().isNotEmpty)
      'generatorVersion=${meta.generatorVersion!.trim()}',
    if ((meta.learningLanguageRaw ?? '').trim().isNotEmpty)
      'learningLanguage=${meta.learningLanguageRaw!.trim()}',
    if ((meta.contentCommunityRaw ?? '').trim().isNotEmpty)
      'contentCommunity=${meta.contentCommunityRaw!.trim()}',
    if ((meta.promptDataTabRaw ?? '').trim().isNotEmpty)
      'promptDataTab=${meta.promptDataTabRaw!.trim()}',
    if ((meta.createdForEmail ?? '').trim().isNotEmpty)
      'createdForEmail=${meta.createdForEmail!.trim()}',
    if ((payload.sourceDraftId ?? '').trim().isNotEmpty)
      'sourceDraftId=${payload.sourceDraftId!.trim()}',
    if ((meta.publishKindRaw ?? '').trim().isNotEmpty)
      'publishKind=${meta.publishKindRaw!.trim()}',
  ];
  return lines.join('\n');
}

List<StorySentenceItem> _mapSentences(
  Map<String, dynamic> core,
  String storyId,
) {
  final raw = core['sentences'];
  if (raw is! List || raw.isEmpty) return const [];

  final sorted = <({int order, Map<String, dynamic> map})>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item.cast<String, dynamic>());
    sorted.add((order: _sentenceSortKey(m, fallback: i), map: m));
  }
  sorted.sort((a, b) {
    final c = a.order.compareTo(b.order);
    return c != 0 ? c : 0;
  });

  final out = <StorySentenceItem>[];
  for (var i = 0; i < sorted.length; i++) {
    final m = sorted[i].map;
    final text = _sentenceJapaneseText(m);
    if (text.isEmpty) continue;
    final content = m['content'];
    final contentMap =
        content is Map ? Map<String, dynamic>.from(content.cast<String, dynamic>()) : null;
    out.add(
      StorySentenceItem(
        id: _optStrOrNewId(m['id']),
        storyId: storyId,
        orderIndex: i,
        japaneseText: text,
        reading: _optStrOrNull(m['reading'] ?? contentMap?['reading']),
        furiganaSpans: _mapFuriganaSpans(m),
        meanings: _mapMeanings(
          m['meanings'] ?? contentMap?['meanings'],
          meaningEn: m['meaning_en'] ?? m['meaningEn'],
          meaningMy: m['meaning_my'] ?? m['meaningMy'],
        ),
        provenance: _mapProvenance(m['provenance']) ?? kNimonImportContentProvenance,
      ),
    );
  }
  return out;
}

int _sentenceSortKey(Map<String, dynamic> m, {required int fallback}) {
  final candidates = [
    m['order'],
    m['orderIndex'],
    m['sentence_order'],
    m['sentenceOrder'],
  ];
  for (final c in candidates) {
    final n = _optInt(c);
    if (n != null) return n;
  }
  return fallback;
}

String _sentenceJapaneseText(Map<String, dynamic> m) {
  final content = m['content'];
  if (content is Map) {
    final cm = Map<String, dynamic>.from(content.cast<String, dynamic>());
    final fromContent = _optStr(
      cm['japaneseText'] ?? cm['japanese_text'] ?? cm['text'] ?? cm['value'],
    );
    if (fromContent.isNotEmpty) return fromContent;
  }
  return _optStr(
    m['japaneseText'] ?? m['japanese_text'] ?? m['text'] ?? m['value'],
  );
}

List<FuriganaSpan> _mapFuriganaSpans(Map<String, dynamic> m) {
  final content = m['content'];
  final spansRaw = m['furiganaSpans'] ??
      m['furigana_spans'] ??
      (content is Map ? (content as Map)['furiganaSpans'] : null) ??
      (content is Map ? (content as Map)['furigana_spans'] : null);
  if (spansRaw is! List) return const [];
  final out = <FuriganaSpan>[];
  for (final x in spansRaw) {
    if (x is! Map) continue;
    final fm = Map<String, dynamic>.from(x.cast<String, dynamic>());
    final start = _optInt(fm['start']) ?? -1;
    final end = _optInt(fm['end']) ?? -1;
    final reading = _optStr(fm['reading']);
    final span = FuriganaSpan(start: start, end: end, reading: reading);
    if (span.isValid) out.add(span);
  }
  return out;
}

List<VocabularyKanjiEntry> _mapVocabularyEntries(Map<String, dynamic>? learn) {
  final entries = _moduleEntries(learn, ['vocabularyKanji', 'vocabulary_kanji']);
  if (entries == null) return const [];

  final out = <VocabularyKanjiEntry>[];
  for (final raw in entries) {
    if (raw is! Map) continue;
    final e = Map<String, dynamic>.from(raw.cast<String, dynamic>());
    final term = _optStr(
      e['termJapanese'] ?? e['term_japanese'] ?? e['term'] ?? e['japanese'],
    );
    if (term.isEmpty) continue;

    var examplePairs = _mapVocabExamplePairs(e);
    String? exampleSentence = _optStrOrNull(e['exampleSentence']);
    LocalizedMeanings? exampleMeanings = _mapMeanings(e['exampleMeanings']);

    if ((exampleSentence == null || exampleSentence.isEmpty) &&
        examplePairs.isNotEmpty) {
      final p = examplePairs.first;
      if (p.sourceExample.trim().isNotEmpty) {
        exampleSentence = p.sourceExample;
      }
      if (exampleMeanings == null) {
        if (p.englishExample.trim().isNotEmpty) {
          exampleMeanings = LocalizedMeanings(en: p.englishExample);
        } else {
          final pairsRaw = e['examplePairs'];
          if (pairsRaw is List && pairsRaw.isNotEmpty && pairsRaw.first is Map) {
            exampleMeanings = _mapMeanings(
              (pairsRaw.first as Map)['meanings'],
            );
          }
        }
      }
    }

    out.add(
      VocabularyKanjiEntry(
        id: _optStrOrNewId(e['id']),
        termJapanese: term,
        type: VocabularyKanjiEntryTypeLabels.fromStorageKey(
          _optStrOrNull(e['type']),
        ),
        reading: _optStrOrNull(e['reading']),
        glosses: _mapMeanings(e['glosses']),
        exampleSentence: exampleSentence,
        exampleMeanings: exampleMeanings,
        examplePairs: examplePairs,
        provenance:
            _mapProvenance(e['provenance']) ?? kNimonImportContentProvenance,
      ),
    );
  }
  return out;
}

List<VocabularyExamplePair> _mapVocabExamplePairs(Map<String, dynamic> e) {
  final raw = e['examplePairs'];
  if (raw is! List) return const [];
  final out = <VocabularyExamplePair>[];
  for (final x in raw.take(3)) {
    if (x is! Map) continue;
    final m = Map<String, dynamic>.from(x.cast<String, dynamic>());
    final source = _optStr(
      m['source'] ??
          m['sourceExample'] ??
          m['japanese'] ??
          m['japaneseText'] ??
          m['jp'],
    );
    var english = _optStr(
      m['english'] ??
          m['englishExample'] ??
          m['en'] ??
          m['meaning_en'],
    );
    if (english.isEmpty && m['meanings'] is Map) {
      final mm = Map<String, dynamic>.from(
        (m['meanings'] as Map).cast<String, dynamic>(),
      );
      english = _optStr(mm['en']);
    }
    if (source.isEmpty && english.isEmpty) continue;
    out.add(
      VocabularyExamplePair(
        sourceExample: source,
        englishExample: english,
      ),
    );
  }
  return out;
}

List<GrammarEntry> _mapGrammarEntries(Map<String, dynamic>? learn) {
  final entries = _moduleEntries(learn, ['grammar']);
  if (entries == null) return const [];

  final out = <GrammarEntry>[];
  for (final raw in entries) {
    if (raw is! Map) continue;
    final e = Map<String, dynamic>.from(raw.cast<String, dynamic>());
    final headline = _optStr(e['headline'] ?? e['title']);
    if (headline.isEmpty) continue;

    out.add(
      GrammarEntry(
        id: _optStrOrNewId(e['id']),
        headline: headline,
        form: _optStrOrNull(e['form']),
        meanings: _mapMeanings(e['meanings']),
        usage: _mapMeanings(e['usage']),
        examples: _mapGrammarExamples(e['examples']),
        mistakeWrong: _optStrOrNull(e['mistakeWrong'] ?? e['mistake_wrong']),
        mistakeCorrect:
            _optStrOrNull(e['mistakeCorrect'] ?? e['mistake_correct']),
        relatedNote: _mapMeanings(e['relatedNote'] ?? e['related_note']),
        provenance: _mapProvenance(e['provenance']) ?? kNimonImportContentProvenance,
      ),
    );
  }
  return out;
}

List<GrammarExample> _mapGrammarExamples(Object? raw) {
  if (raw is! List) return const [];
  final out = <GrammarExample>[];
  for (final x in raw) {
    if (x is! Map) continue;
    final m = Map<String, dynamic>.from(x.cast<String, dynamic>());
    final jp = _optStr(m['japanese'] ?? m['text']);
    final ex = GrammarExample(
      japanese: jp,
      meanings: _mapMeanings(m['meanings']),
    );
    if (!ex.isEmptyV1) out.add(ex);
  }
  return out;
}

List<QuizEntry> _mapQuizEntries(Map<String, dynamic>? learn) {
  final entries = _moduleEntries(learn, ['quiz']);
  if (entries == null) return const [];

  final out = <QuizEntry>[];
  for (final raw in entries) {
    if (raw is! Map) continue;
    final e = Map<String, dynamic>.from(raw.cast<String, dynamic>());
    final prompt = _optStr(e['prompt']);
    if (prompt.isEmpty) continue;

    final optionsRaw = e['options'];
    if (optionsRaw is! List || optionsRaw.length != 4) continue;

    final options = <String>[
      for (final o in optionsRaw) _optStr(o),
    ];
    if (options.any((o) => o.isEmpty)) continue;

    final correctIndex = _optInt(e['correctIndex'] ?? e['correct_index']);
    if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
      continue;
    }

    out.add(
      QuizEntry(
        id: _optStrOrNewId(e['id']),
        category: CreatorQuizCategoryLabels.fromStorageKey(
          _optStrOrNull(e['category']),
        ),
        prompt: prompt,
        options: options,
        correctIndex: correctIndex,
        explanations: _mapMeanings(e['explanations']),
        sourceNote: _optStrOrNull(e['sourceNote'] ?? e['source_note']),
        provenance: _mapProvenance(e['provenance']) ?? kNimonImportContentProvenance,
      ),
    );
  }
  return out;
}

StoryAudioAsset? _mapStoryAudio(Map<String, dynamic>? learn) {
  final audioRoot = _nestedMap(learn, ['audio']);
  if (audioRoot == null) return null;

  final sa = _nestedMap(audioRoot, ['storyAudio', 'story_audio']);
  if (sa == null) return null;

  final sourceUrl = _optStrOrNull(sa['sourceUrl'] ?? sa['source_url']);
  final localPath = _optStrOrNull(sa['localPath'] ?? sa['local_path']);
  final localFileName = _optStrOrNull(
    sa['localFileName'] ?? sa['local_file_name'] ?? sa['displayName'],
  );

  if (sourceUrl == null && localPath == null && localFileName == null) {
    return null;
  }

  final asset = StoryAudioAsset(
    id: _optStrOrNewId(sa['id']),
    sourceUrl: sourceUrl,
    localPath: localPath,
    localFileName: localFileName,
    localExtension: _optStrOrNull(sa['localExtension'] ?? sa['local_extension']),
    localSizeBytes: _optInt(sa['localSizeBytes'] ?? sa['local_size_bytes']),
    displayName: _optStrOrNull(sa['displayName'] ?? sa['display_name']),
    durationSeconds: _optInt(sa['durationSeconds'] ?? sa['duration_seconds']),
    provenance: _mapProvenance(sa['provenance']) ?? kNimonImportContentProvenance,
  );

  return asset.isValidV1 ? asset : null;
}

List<dynamic>? _moduleEntries(
  Map<String, dynamic>? learn,
  List<String> moduleKeys,
) {
  final module = _nestedMap(learn, moduleKeys);
  if (module == null) return null;
  final entries = module['entries'];
  if (entries is! List) return null;
  return entries;
}

Map<String, dynamic>? _nestedMap(
  Map<String, dynamic>? root,
  List<String> keys,
) {
  if (root == null) return null;
  for (final key in keys) {
    final v = root[key];
    if (v is Map) {
      return Map<String, dynamic>.from(v.cast<String, dynamic>());
    }
  }
  return null;
}

LocalizedMeanings? _mapMeanings(
  Object? raw, {
  Object? meaningEn,
  Object? meaningMy,
}) {
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw.cast<String, dynamic>());
    final en = _optStrOrNull(m['en']);
    final my = _optStrOrNull(m['my']);
    final byRaw = m['byLanguage'] ?? m['by_language'];
    final by = <String, String>{};
    if (byRaw is Map) {
      for (final e in byRaw.entries) {
        final v = _optStr(e.value);
        if (v.isNotEmpty) by[e.key.toString()] = v;
      }
    }
    if (en == null && my == null && by.isEmpty) {
      // fall through to flat fields
    } else {
      return LocalizedMeanings(en: en, my: my, byLanguage: by);
    }
  }

  final en = _optStr(meaningEn);
  final my = _optStr(meaningMy);
  if (en.isEmpty && my.isEmpty) return null;
  return LocalizedMeanings(
    en: en.isEmpty ? null : en,
    my: my.isEmpty ? null : my,
  );
}

ContentProvenance? _mapProvenance(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw.cast<String, dynamic>());
  final modeRaw = _optStr(m['sourceMode'] ?? m['source_mode']);
  final mode = ContentSourceMode.values.firstWhere(
    (e) => e.name == modeRaw,
    orElse: () => ContentSourceMode.aiDraft,
  );
  final reviewed = m['lastReviewedByCreator'] ?? m['last_reviewed_by_creator'];
  final lastReviewed = reviewed is bool ? reviewed : false;
  return ContentProvenance(
    sourceMode: mode,
    lastReviewedByCreator: lastReviewed,
  );
}

String _optStrOrNewId(Object? v) {
  final s = _optStr(v);
  return s.isEmpty ? _uuid.v4() : s;
}

String _optStr(Object? v) {
  if (v == null) return '';
  return v.toString().trim();
}

String? _optStrOrNull(Object? v) {
  final s = _optStr(v);
  return s.isEmpty ? null : s;
}

int? _optInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}
