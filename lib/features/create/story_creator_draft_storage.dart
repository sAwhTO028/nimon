import 'dart:convert';

import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V1: local creator drafts persisted on-device (multi-draft).
///
/// Storage model (SharedPreferences):
/// - index: list of draft ids
/// - per-draft json payload + per-draft savedAt
/// - optional active draft id (used only when callers don't specify an id)
///
/// NOTE: older builds stored exactly one draft under `_draftKey` — this file keeps
/// a small migration path so existing users keep their draft.
abstract final class StoryCreatorDraftStorage {
  StoryCreatorDraftStorage._();

  static const _indexKey = 'nimon_creator_drafts_v1_index';
  static const _activeIdKey = 'nimon_creator_drafts_v1_active_id';
  static const _draftKeyPrefix = 'nimon_creator_draft_v1_';
  static const _savedAtKeyPrefix = 'nimon_creator_draft_v1_saved_at_';

  // Legacy single-draft keys (pre multi-draft).
  static const _legacyDraftKey = 'nimon_creator_current_draft_v1';
  static const _legacySavedAtKey = 'nimon_creator_current_draft_v1_saved_at';

  static String _draftKeyForId(String id) => '$_draftKeyPrefix$id';
  static String _savedAtKeyForId(String id) => '$_savedAtKeyPrefix$id';

  static Future<List<String>> _loadIndex(SharedPreferences p) async {
    final raw = p.getString(_indexKey);
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      final ids = <String>[
        for (final x in decoded)
          if (x is String && x.trim().isNotEmpty) x.trim(),
      ];
      return ids;
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> _saveIndex(SharedPreferences p, List<String> ids) async {
    await p.setString(_indexKey, jsonEncode(ids));
  }

  static Future<void> _ensureLegacyMigrated(SharedPreferences p) async {
    // If index already exists, assume migrated.
    final existingIndex = p.getString(_indexKey);
    if (existingIndex != null && existingIndex.trim().isNotEmpty) return;

    final raw = p.getString(_legacyDraftKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      final draft = _fromJsonCreatorStoryV1(m);
      final id = draft.id.trim();
      if (id.isEmpty) return;

      // Persist under new keys.
      final now = DateTime.now().toUtc();
      await p.setString(_draftKeyForId(id), jsonEncode(_toJson(draft)));
      await p.setString(_savedAtKeyForId(id), now.toIso8601String());
      await _saveIndex(p, <String>[id]);
      await p.setString(_activeIdKey, id);

      // Remove legacy keys.
      await p.remove(_legacyDraftKey);
      await p.remove(_legacySavedAtKey);
    } catch (_) {
      // Ignore corrupt legacy payload.
    }
  }

  static Future<bool> exists() async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final ids = await _loadIndex(p);
    return ids.isNotEmpty;
  }

  /// Whether a draft payload exists for [draftId] (does not imply indexed/active).
  static Future<bool> hasDraft(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return false;
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final raw = p.getString(_draftKeyForId(id));
    return raw != null && raw.trim().isNotEmpty;
  }

  /// Saved-at timestamp for a specific draft id (or active draft when omitted).
  static Future<DateTime?> loadSavedAt({String? draftId}) async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final id = draftId?.trim().isNotEmpty == true
        ? draftId!.trim()
        : p.getString(_activeIdKey);
    if (id == null || id.trim().isEmpty) return null;
    final raw = p.getString(_savedAtKeyForId(id.trim()));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  /// Clears a specific draft. When [draftId] is omitted, clears the active draft id (if any).
  static Future<void> clear({String? draftId}) async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final ids = (await _loadIndex(p)).toList();
    final id = draftId?.trim().isNotEmpty == true
        ? draftId!.trim()
        : p.getString(_activeIdKey);
    if (id == null || id.trim().isEmpty) return;
    final cleanedId = id.trim();
    ids.removeWhere((x) => x == cleanedId);
    await p.remove(_draftKeyForId(cleanedId));
    await p.remove(_savedAtKeyForId(cleanedId));
    await _saveIndex(p, ids);
    if (p.getString(_activeIdKey) == cleanedId) {
      await p.remove(_activeIdKey);
    }
  }

  static Future<void> save(CreatorStoryV1 story) async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final now = DateTime.now().toUtc();
    final id = story.id.trim();
    if (id.isEmpty) return;
    final ids = (await _loadIndex(p)).toList();
    if (!ids.contains(id)) ids.insert(0, id);
    await _saveIndex(p, ids);
    await p.setString(_activeIdKey, id);
    await p.setString(_draftKeyForId(id), jsonEncode(_toJson(story)));
    await p.setString(_savedAtKeyForId(id), now.toIso8601String());
  }

  /// Loads a specific draft id (or active draft when omitted).
  static Future<CreatorStoryV1?> load({String? draftId}) async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final id = draftId?.trim().isNotEmpty == true
        ? draftId!.trim()
        : p.getString(_activeIdKey);
    if (id == null || id.trim().isEmpty) return null;
    final raw = p.getString(_draftKeyForId(id.trim()));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      return _fromJsonCreatorStoryV1(m);
    } catch (_) {
      return null;
    }
  }

  /// Returns all known draft ids (most-recent-first).
  static Future<List<String>> loadAllIds() async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    return _loadIndex(p);
  }

  /// Loads all drafts (best-effort; skips corrupt entries).
  static Future<List<CreatorStoryV1>> loadAllDrafts() async {
    final p = await SharedPreferences.getInstance();
    await _ensureLegacyMigrated(p);
    final ids = await _loadIndex(p);
    final out = <CreatorStoryV1>[];
    for (final id in ids) {
      final raw = p.getString(_draftKeyForId(id));
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final m = jsonDecode(raw) as Map<String, Object?>;
        final d = _fromJsonCreatorStoryV1(m);
        out.add(d);
      } catch (_) {
        // ignore corrupt draft
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // JSON (manual, lightweight) — tolerant of missing fields
  // ---------------------------------------------------------------------------

  static Map<String, Object?> _toJson(CreatorStoryV1 s) {
    final out = <String, Object?>{
      'basics': _toJsonBasics(s.basics),
      'sentences': [for (final x in s.sentences) _toJsonSentence(x)],
      'vocabularyKanji': _toJsonVocabLayer(s.vocabularyKanji),
      'grammar': _toJsonGrammarLayer(s.grammar),
      'quiz': _toJsonQuizLayer(s.quiz),
      'audio': _toJsonAudioLayer(s.audio),
      'publishState': s.publishState.storageKey,
      'moduleWorkflowStatuses': {
        for (final e in s.moduleWorkflowStatuses.entries)
          e.key.storageKey: e.value.storageKey,
      },
    };
    final pm = s.publishedMonoId?.trim();
    if (pm != null && pm.isNotEmpty) {
      out['publishedMonoId'] = pm;
    }
    if (s.hasUnpublishedCoreChanges != null) {
      out['hasUnpublishedCoreChanges'] = s.hasUnpublishedCoreChanges!;
    }
    return out;
  }

  static Map<String, Object?> _toJsonBasics(StoryBasics b) {
    return {
      'storyId': b.storyId,
      'title': b.title,
      'category': b.category,
      'level': b.level,
      'description': b.description,
      'promptSourceNote': b.promptSourceNote,
      'targetDurationBandKey': b.targetDurationBandKey,
      'coverImageUrl': b.coverImageUrl,
      'creatorOwnerId': b.creatorOwnerId,
      'createdAt': b.createdAt.toIso8601String(),
      'updatedAt': b.updatedAt.toIso8601String(),
    };
  }

  static Map<String, Object?> _toJsonSentence(StorySentenceItem s) {
    return {
      'id': s.id,
      'storyId': s.storyId,
      'orderIndex': s.orderIndex,
      'japaneseText': s.japaneseText,
      'reading': s.reading,
      'furiganaSpans': [
        for (final f in s.furiganaSpans)
          {
            'start': f.start,
            'end': f.end,
            'reading': f.reading,
          },
      ],
      'meanings': s.meanings == null ? null : _toJsonMeanings(s.meanings!),
      'audioStartMs': s.audioStartMs,
      'audioEndMs': s.audioEndMs,
      'provenance': s.provenance == null ? null : _toJsonProv(s.provenance!),
    };
  }

  static Map<String, Object?> _toJsonMeanings(LocalizedMeanings m) {
    return {
      'en': m.en,
      'my': m.my,
      'byLanguage': m.byLanguage,
    };
  }

  static Map<String, Object?> _toJsonProv(ContentProvenance p) {
    return {
      'sourceMode': p.sourceMode.name,
      'lastReviewedByCreator': p.lastReviewedByCreator,
    };
  }

  static Map<String, Object?> _toJsonVocabLayer(VocabularyKanjiLayer l) {
    return {
      'entries': [
        for (final e in l.entries)
          {
            'id': e.id,
            'termJapanese': e.termJapanese,
            'type': e.type.storageKey,
            'reading': e.reading,
            'glosses': e.glosses == null ? null : _toJsonMeanings(e.glosses!),
            'examplePairs': [
              for (final p in e.examplePairs)
                {
                  'source': p.sourceExample,
                  'english': p.englishExample,
                },
            ],
            'exampleSentence': e.exampleSentence,
            'exampleMeanings': e.exampleMeanings == null
                ? null
                : _toJsonMeanings(e.exampleMeanings!),
            'provenance':
                e.provenance == null ? null : _toJsonProv(e.provenance!),
          },
      ],
    };
  }

  static Map<String, Object?> _toJsonGrammarLayer(GrammarLayer l) {
    return {
      'entries': [
        for (final e in l.entries)
          {
            'id': e.id,
            'headline': e.headline,
            'form': e.form,
            'meanings':
                e.meanings == null ? null : _toJsonMeanings(e.meanings!),
            'usage': e.usage == null ? null : _toJsonMeanings(e.usage!),
            'examples': [
              for (final ex in e.examples)
                {
                  'japanese': ex.japanese,
                  'meanings': ex.meanings == null
                      ? null
                      : _toJsonMeanings(ex.meanings!),
                },
            ],
            'mistakeWrong': e.mistakeWrong,
            'mistakeCorrect': e.mistakeCorrect,
            'relatedNote':
                e.relatedNote == null ? null : _toJsonMeanings(e.relatedNote!),
            'provenance':
                e.provenance == null ? null : _toJsonProv(e.provenance!),
          },
      ],
    };
  }

  static Map<String, Object?> _toJsonQuizLayer(QuizLayer l) {
    return {
      'entries': [
        for (final e in l.entries)
          {
            'id': e.id,
            'category': e.category.storageKey,
            'prompt': e.prompt,
            'options': e.options,
            'correctIndex': e.correctIndex,
            'explanations': e.explanations == null
                ? null
                : _toJsonMeanings(e.explanations!),
            'sourceNote': e.sourceNote,
            'provenance':
                e.provenance == null ? null : _toJsonProv(e.provenance!),
          },
      ],
    };
  }

  static Map<String, Object?> _toJsonAudioLayer(AudioLayer l) {
    return {
      'storyAudio': l.storyAudio == null
          ? null
          : {
              'id': l.storyAudio!.id,
              'sourceUrl': l.storyAudio!.sourceUrl,
              'localFileName': l.storyAudio!.localFileName,
              'localPath': l.storyAudio!.localPath,
              'localSizeBytes': l.storyAudio!.localSizeBytes,
              'localExtension': l.storyAudio!.localExtension,
              'displayName': l.storyAudio!.displayName,
              'durationSeconds': l.storyAudio!.durationSeconds,
              'provenance': l.storyAudio!.provenance == null
                  ? null
                  : _toJsonProv(l.storyAudio!.provenance!),
            },
    };
  }

  static CreatorStoryV1 _fromJsonCreatorStoryV1(Map<String, Object?> m) {
    final basics =
        _fromJsonBasics((m['basics'] as Map).cast<String, Object?>());

    final moduleStatusesRaw =
        (m['moduleWorkflowStatuses'] as Map?)?.cast<String, Object?>() ??
            const {};
    final moduleStatuses = <LearnModuleId, LearnModuleTaskStatus>{
      for (final id in LearnModuleId.values)
        id: _taskStatusFromKey(
          moduleStatusesRaw[id.storageKey] as String?,
        ),
    };

    final sentencesRaw = (m['sentences'] as List?) ?? const [];
    final sentences = <StorySentenceItem>[
      for (final x in sentencesRaw)
        _fromJsonSentence((x as Map).cast<String, Object?>()),
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final publish = _publishFromKey(m['publishState'] as String?);
    final vocab = _fromJsonVocabLayer(
      (m['vocabularyKanji'] as Map?)?.cast<String, Object?>(),
    );
    final grammar = _fromJsonGrammarLayer(
      (m['grammar'] as Map?)?.cast<String, Object?>(),
    );
    final quiz = _fromJsonQuizLayer(
      (m['quiz'] as Map?)?.cast<String, Object?>(),
    );
    final audio = _fromJsonAudioLayer(
      (m['audio'] as Map?)?.cast<String, Object?>(),
    );

    final pmRaw = (m['publishedMonoId'] as String?)?.trim();
    return CreatorStoryV1(
      basics: basics,
      sentences: sentences,
      vocabularyKanji: vocab,
      grammar: grammar,
      quiz: quiz,
      audio: audio,
      publishState: publish,
      moduleWorkflowStatuses: moduleStatuses,
      publishedMonoId: (pmRaw == null || pmRaw.isEmpty) ? null : pmRaw,
      hasUnpublishedCoreChanges:
          _draftOptionalBoolFromJson(m['hasUnpublishedCoreChanges']),
    );
  }

  static bool? _draftOptionalBoolFromJson(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return null;
  }

  static StoryBasics _fromJsonBasics(Map<String, Object?> m) {
    DateTime parseDt(Object? v) {
      final s = (v as String?)?.trim();
      return DateTime.tryParse(s ?? '') ?? DateTime.now();
    }

    return StoryBasics(
      storyId: (m['storyId'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      level: (m['level'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      promptSourceNote: (m['promptSourceNote'] as String?) ?? '',
      targetDurationBandKey:
          (m['targetDurationBandKey'] as String?)?.trim().isEmpty == true
              ? null
              : (m['targetDurationBandKey'] as String?),
      coverImageUrl: (m['coverImageUrl'] as String?)?.trim().isEmpty == true
          ? null
          : (m['coverImageUrl'] as String?),
      creatorOwnerId: (m['creatorOwnerId'] as String?) ?? '',
      createdAt: parseDt(m['createdAt']),
      updatedAt: parseDt(m['updatedAt']),
    );
  }

  static StorySentenceItem _fromJsonSentence(Map<String, Object?> m) {
    final spansRaw = (m['furiganaSpans'] as List?) ?? const [];
    final spans = <FuriganaSpan>[
      for (final x in spansRaw)
        () {
          final fm = (x as Map).cast<String, Object?>();
          final start = (fm['start'] as int?) ?? -1;
          final end = (fm['end'] as int?) ?? -1;
          final reading = (fm['reading'] as String?) ?? '';
          final f = FuriganaSpan(start: start, end: end, reading: reading);
          return f;
        }(),
    ].where((f) => f.isValid).toList();

    return StorySentenceItem(
      id: (m['id'] as String?) ?? '',
      storyId: (m['storyId'] as String?) ?? '',
      orderIndex: (m['orderIndex'] as int?) ?? 0,
      japaneseText: (m['japaneseText'] as String?) ?? '',
      reading: (m['reading'] as String?)?.trim().isEmpty == true
          ? null
          : (m['reading'] as String?),
      furiganaSpans: spans,
      meanings: _fromJsonMeanings(m['meanings']),
      audioStartMs: (m['audioStartMs'] as int?),
      audioEndMs: (m['audioEndMs'] as int?),
      provenance: _fromJsonProv(m['provenance']),
    );
  }

  static LocalizedMeanings? _fromJsonMeanings(Object? v) {
    if (v == null) return null;
    final m = (v as Map).cast<String, Object?>();
    final en = (m['en'] as String?)?.trim();
    final my = (m['my'] as String?)?.trim();
    final by = (m['byLanguage'] as Map?)?.cast<String, Object?>() ?? const {};
    final byStr = <String, String>{
      for (final e in by.entries)
        if ((e.value as String?)?.trim().isNotEmpty == true)
          e.key: (e.value as String).trim(),
    };
    if ((en == null || en.isEmpty) &&
        (my == null || my.isEmpty) &&
        byStr.isEmpty) {
      return null;
    }
    return LocalizedMeanings(
      en: (en == null || en.isEmpty) ? null : en,
      my: (my == null || my.isEmpty) ? null : my,
      byLanguage: byStr,
    );
  }

  static ContentProvenance? _fromJsonProv(Object? v) {
    if (v == null) return null;
    final m = (v as Map).cast<String, Object?>();
    final modeRaw = (m['sourceMode'] as String?) ?? 'manual';
    final mode = ContentSourceMode.values.firstWhere(
      (e) => e.name == modeRaw,
      orElse: () => ContentSourceMode.manual,
    );
    final reviewed = (m['lastReviewedByCreator'] as bool?) ?? true;
    return ContentProvenance(sourceMode: mode, lastReviewedByCreator: reviewed);
  }

  static List<VocabularyExamplePair> _vocabExamplePairsFromMap(
    Map<String, Object?> e,
  ) {
    final raw = e['examplePairs'];
    if (raw is List && raw.isNotEmpty) {
      final out = <VocabularyExamplePair>[];
      for (final x in raw.take(3)) {
        if (x is! Map) continue;
        final m = x.cast<String, Object?>();
        out.add(
          VocabularyExamplePair(
            sourceExample: (m['source'] as String?) ?? '',
            englishExample:
                (m['english'] as String?) ?? (m['en'] as String?) ?? '',
          ),
        );
      }
      final nonempty = [
        for (final p in out)
          if (p.sourceExample.trim().isNotEmpty ||
              p.englishExample.trim().isNotEmpty)
            p,
      ];
      if (nonempty.isNotEmpty) return nonempty;
    }
    final jp = (e['exampleSentence'] as String?)?.trim() ?? '';
    final em = _fromJsonMeanings(e['exampleMeanings']);
    final en = em?.en?.trim() ?? '';
    final my = em?.my?.trim() ?? '';
    if (jp.isEmpty && en.isEmpty && my.isEmpty) return const [];
    return [
      VocabularyExamplePair(
        sourceExample: (e['exampleSentence'] as String?) ?? '',
        englishExample: en.isNotEmpty ? en : my,
      ),
    ];
  }

  static VocabularyKanjiLayer _fromJsonVocabLayer(Map<String, Object?>? m) {
    final entriesRaw = (m?['entries'] as List?) ?? const [];
    final entries = <VocabularyKanjiEntry>[
      for (final x in entriesRaw)
        () {
          final e = (x as Map).cast<String, Object?>();
          return VocabularyKanjiEntry(
            id: (e['id'] as String?) ?? '',
            termJapanese: (e['termJapanese'] as String?) ?? '',
            type: VocabularyKanjiEntryTypeLabels.fromStorageKey(
              e['type'] as String?,
            ),
            reading: (e['reading'] as String?)?.trim().isEmpty == true
                ? null
                : (e['reading'] as String?),
            glosses: _fromJsonMeanings(e['glosses']),
            exampleSentence:
                (e['exampleSentence'] as String?)?.trim().isEmpty == true
                    ? null
                    : (e['exampleSentence'] as String?),
            exampleMeanings: _fromJsonMeanings(e['exampleMeanings']),
            examplePairs: _vocabExamplePairsFromMap(e),
            provenance: _fromJsonProv(e['provenance']),
          );
        }(),
    ];
    return VocabularyKanjiLayer(entries: entries);
  }

  static GrammarLayer _fromJsonGrammarLayer(Map<String, Object?>? m) {
    final entriesRaw = (m?['entries'] as List?) ?? const [];
    final entries = <GrammarEntry>[
      for (final x in entriesRaw)
        () {
          final e = (x as Map).cast<String, Object?>();
          return GrammarEntry(
            id: (e['id'] as String?) ?? '',
            headline: (e['headline'] as String?) ?? '',
            form: (e['form'] as String?)?.trim().isEmpty == true
                ? null
                : (e['form'] as String?),
            meanings: _fromJsonMeanings(e['meanings']),
            usage: _fromJsonMeanings(e['usage']),
            examples: _fromJsonGrammarExamples(e['examples']),
            mistakeWrong: (e['mistakeWrong'] as String?)?.trim().isEmpty == true
                ? null
                : (e['mistakeWrong'] as String?),
            mistakeCorrect:
                (e['mistakeCorrect'] as String?)?.trim().isEmpty == true
                    ? null
                    : (e['mistakeCorrect'] as String?),
            relatedNote: _fromJsonMeanings(e['relatedNote']),
            provenance: _fromJsonProv(e['provenance']),
          );
        }(),
    ];
    return GrammarLayer(entries: entries);
  }

  static List<GrammarExample> _fromJsonGrammarExamples(Object? v) {
    final raw = (v as List?) ?? const [];
    final out = <GrammarExample>[];
    for (final x in raw) {
      final m = (x as Map).cast<String, Object?>();
      final jp = (m['japanese'] as String?) ?? '';
      final meanings = _fromJsonMeanings(m['meanings']);
      final ex = GrammarExample(japanese: jp, meanings: meanings);
      if (!ex.isEmptyV1) out.add(ex);
    }
    return out;
  }

  static QuizLayer _fromJsonQuizLayer(Map<String, Object?>? m) {
    final entriesRaw = (m?['entries'] as List?) ?? const [];
    final entries = <QuizEntry>[
      for (final x in entriesRaw)
        () {
          final e = (x as Map).cast<String, Object?>();
          final optsRaw = (e['options'] as List?) ?? const [];
          final opts = <String>[
            for (final o in optsRaw) (o as String?) ?? '',
          ];
          final padded = <String>[
            ...opts.take(4),
            for (var i = opts.length; i < 4; i++) '',
          ];
          return QuizEntry(
            id: (e['id'] as String?) ?? '',
            category: CreatorQuizCategoryLabels.fromStorageKey(
              e['category'] as String?,
            ),
            prompt: (e['prompt'] as String?) ?? '',
            options: padded,
            correctIndex: (e['correctIndex'] as int?) ?? 0,
            explanations: _fromJsonMeanings(e['explanations']),
            sourceNote: (e['sourceNote'] as String?)?.trim().isEmpty == true
                ? null
                : (e['sourceNote'] as String?),
            provenance: _fromJsonProv(e['provenance']),
          );
        }(),
    ];
    return QuizLayer(entries: entries);
  }

  static AudioLayer _fromJsonAudioLayer(Map<String, Object?>? m) {
    final raw = m?['storyAudio'];
    if (raw == null) return const AudioLayer(storyAudio: null);
    final a = (raw as Map).cast<String, Object?>();
    return AudioLayer(
      storyAudio: StoryAudioAsset(
        id: (a['id'] as String?) ?? '',
        sourceUrl: (a['sourceUrl'] as String?)?.trim().isEmpty == true
            ? null
            : (a['sourceUrl'] as String?),
        localFileName: (a['localFileName'] as String?)?.trim().isEmpty == true
            ? null
            : (a['localFileName'] as String?),
        localPath: (a['localPath'] as String?)?.trim().isEmpty == true
            ? null
            : (a['localPath'] as String?),
        localSizeBytes: (a['localSizeBytes'] as int?),
        localExtension: (a['localExtension'] as String?)?.trim().isEmpty == true
            ? null
            : (a['localExtension'] as String?),
        displayName: (a['displayName'] as String?)?.trim().isEmpty == true
            ? null
            : (a['displayName'] as String?),
        durationSeconds: (a['durationSeconds'] as int?),
        provenance: _fromJsonProv(a['provenance']),
      ),
    );
  }

  static StoryPublishState _publishFromKey(String? k) {
    return switch ((k ?? '').trim()) {
      'reading_only_published' => StoryPublishState.readingOnlyPublished,
      'full_learn_published' => StoryPublishState.fullLearnPublished,
      _ => StoryPublishState.draft,
    };
  }

  static LearnModuleTaskStatus _taskStatusFromKey(String? k) {
    return switch ((k ?? '').trim()) {
      'in_progress' => LearnModuleTaskStatus.inProgress,
      'completed' => LearnModuleTaskStatus.completed,
      _ => LearnModuleTaskStatus.notStarted,
    };
  }
}

/// V1: per-draft resume metadata persisted on-device.
///
/// Stored separately from the draft JSON to avoid changing the draft schema.
enum CreatorLastActiveModule {
  storyBasics,
  storytelling,
  semantics,
  grammar,
  quizzes,
  listening,
  review,
}

class CreatorDraftResumeMeta {
  const CreatorDraftResumeMeta({
    required this.draftId,
    required this.lastActiveModule,
    required this.lastActiveSubPage,
    required this.lastEnteredAtUtc,
    required this.lastEditedAtUtc,
  });

  final String draftId;
  final CreatorLastActiveModule lastActiveModule;
  final String? lastActiveSubPage;
  final DateTime lastEnteredAtUtc;
  final DateTime lastEditedAtUtc;

  static CreatorDraftResumeMeta initial({
    required String draftId,
    CreatorLastActiveModule module = CreatorLastActiveModule.storyBasics,
    String? subPage,
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now().toUtc());
    return CreatorDraftResumeMeta(
      draftId: draftId,
      lastActiveModule: module,
      lastActiveSubPage: subPage,
      lastEnteredAtUtc: now,
      lastEditedAtUtc: now,
    );
  }

  CreatorDraftResumeMeta copyWith({
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    bool clearSubPage = false,
    DateTime? lastEnteredAtUtc,
    DateTime? lastEditedAtUtc,
  }) {
    return CreatorDraftResumeMeta(
      draftId: draftId,
      lastActiveModule: lastActiveModule ?? this.lastActiveModule,
      lastActiveSubPage:
          clearSubPage ? null : (lastActiveSubPage ?? this.lastActiveSubPage),
      lastEnteredAtUtc: lastEnteredAtUtc ?? this.lastEnteredAtUtc,
      lastEditedAtUtc: lastEditedAtUtc ?? this.lastEditedAtUtc,
    );
  }

  static String _moduleKey(CreatorLastActiveModule m) => switch (m) {
        CreatorLastActiveModule.storyBasics => 'story_basics',
        CreatorLastActiveModule.storytelling => 'storytelling',
        CreatorLastActiveModule.semantics => 'semantics',
        CreatorLastActiveModule.grammar => 'grammar',
        CreatorLastActiveModule.quizzes => 'quizzes',
        CreatorLastActiveModule.listening => 'listening',
        CreatorLastActiveModule.review => 'review',
      };

  static CreatorLastActiveModule _moduleFromKey(String? k) {
    return switch ((k ?? '').trim()) {
      'story_basics' => CreatorLastActiveModule.storyBasics,
      'storytelling' => CreatorLastActiveModule.storytelling,
      'semantics' => CreatorLastActiveModule.semantics,
      'grammar' => CreatorLastActiveModule.grammar,
      'quizzes' => CreatorLastActiveModule.quizzes,
      'listening' => CreatorLastActiveModule.listening,
      'review' => CreatorLastActiveModule.review,
      _ => CreatorLastActiveModule.storytelling,
    };
  }

  Map<String, Object?> toJson() {
    return {
      'draftId': draftId,
      'lastActiveModule': _moduleKey(lastActiveModule),
      'lastActiveSubPage': lastActiveSubPage,
      'lastEnteredAtUtc': lastEnteredAtUtc.toIso8601String(),
      'lastEditedAtUtc': lastEditedAtUtc.toIso8601String(),
    };
  }

  static CreatorDraftResumeMeta? fromJson(Object? raw,
      {required String draftId}) {
    if (raw is! Map) return null;
    final m = raw.cast<String, Object?>();
    DateTime parseDt(Object? v) {
      final s = (v as String?)?.trim();
      return DateTime.tryParse(s ?? '')?.toUtc() ?? DateTime.now().toUtc();
    }

    return CreatorDraftResumeMeta(
      draftId: draftId,
      lastActiveModule: _moduleFromKey(m['lastActiveModule'] as String?),
      lastActiveSubPage:
          (m['lastActiveSubPage'] as String?)?.trim().isEmpty == true
              ? null
              : (m['lastActiveSubPage'] as String?),
      lastEnteredAtUtc: parseDt(m['lastEnteredAtUtc']),
      lastEditedAtUtc: parseDt(m['lastEditedAtUtc']),
    );
  }
}

abstract final class StoryCreatorDraftResumeStorage {
  StoryCreatorDraftResumeStorage._();

  static const _metaKeyPrefix = 'nimon_creator_draft_v1_resume_meta_';

  static String _key(String draftId) => '$_metaKeyPrefix${draftId.trim()}';

  static Future<CreatorDraftResumeMeta?> loadMeta(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(id));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return CreatorDraftResumeMeta.fromJson(decoded, draftId: id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMeta(CreatorDraftResumeMeta meta) async {
    final id = meta.draftId.trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(id), jsonEncode(meta.toJson()));
  }

  static Future<void> clearMeta(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(id));
  }

  static Future<void> ensureInit(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    final existing = await loadMeta(id);
    if (existing != null) return;
    await saveMeta(CreatorDraftResumeMeta.initial(draftId: id));
  }

  static Future<void> recordLastActive({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    // Avoid creating resume metadata for drafts that don't exist yet (new untouched sessions).
    final exists = await StoryCreatorDraftStorage.hasDraft(id);
    if (!exists) return;
    final now = DateTime.now().toUtc();
    final existing = await loadMeta(id);
    final next =
        (existing ?? CreatorDraftResumeMeta.initial(draftId: id)).copyWith(
      lastActiveModule: module,
      lastActiveSubPage:
          subPage?.trim().isEmpty == true ? null : subPage?.trim(),
      clearSubPage: subPage == null,
      lastEnteredAtUtc: now,
    );
    await saveMeta(next);
  }

  static Future<void> touchEdited({
    required String draftId,
    DateTime? atUtc,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    final now = (atUtc ?? DateTime.now().toUtc());
    final existing = await loadMeta(id);
    final next =
        (existing ?? CreatorDraftResumeMeta.initial(draftId: id)).copyWith(
      lastEditedAtUtc: now,
    );
    await saveMeta(next);
  }
}
