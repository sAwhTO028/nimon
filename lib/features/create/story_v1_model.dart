import 'package:uuid/uuid.dart';

// -----------------------------------------------------------------------------
// Publish & workflow enums
// -----------------------------------------------------------------------------

/// Story lifecycle for creator + reader (V1 session; JSON-ready names via [storageKey]).
enum StoryPublishState {
  draft,
  readingOnlyPublished,
  fullLearnPublished,
}

extension StoryPublishStateStorage on StoryPublishState {
  String get storageKey => switch (this) {
        StoryPublishState.draft => 'draft',
        StoryPublishState.readingOnlyPublished => 'reading_only_published',
        StoryPublishState.fullLearnPublished => 'full_learn_published',
      };
}

/// Learn add-on buckets (separate layers in [CreatorStoryV1]).
enum LearnModuleId {
  vocabularyKanji,
  grammar,
  quiz,
  audio,
}

extension LearnModuleIdLabels on LearnModuleId {
  String get displayTitle => switch (this) {
        LearnModuleId.vocabularyKanji => 'Vocabulary / Kanji',
        LearnModuleId.grammar => 'Grammar',
        LearnModuleId.quiz => 'Quiz',
        LearnModuleId.audio => 'Listening / Audio',
      };

  /// Stable id for APIs / analytics.
  String get storageKey => switch (this) {
        LearnModuleId.vocabularyKanji => 'vocabulary_kanji',
        LearnModuleId.grammar => 'grammar',
        LearnModuleId.quiz => 'quiz',
        LearnModuleId.audio => 'audio',
      };
}

/// Creator-facing progress (independent of whether V1 data checks pass).
enum LearnModuleTaskStatus {
  notStarted,
  inProgress,
  completed,
}

extension LearnModuleTaskStatusStorage on LearnModuleTaskStatus {
  String get storageKey => switch (this) {
        LearnModuleTaskStatus.notStarted => 'not_started',
        LearnModuleTaskStatus.inProgress => 'in_progress',
        LearnModuleTaskStatus.completed => 'completed',
      };
}

// -----------------------------------------------------------------------------
// AI-ready provenance (manual-first; no AI calls in V1)
// -----------------------------------------------------------------------------

enum ContentSourceMode {
  manual,
  aiDraft,
  aiEdited,
}

/// Attached to sentences / module rows for future AI-assisted workflows.
class ContentProvenance {
  const ContentProvenance({
    this.sourceMode = ContentSourceMode.manual,
    this.lastReviewedByCreator = true,
  });

  final ContentSourceMode sourceMode;
  /// False when creator has not yet reviewed an AI-generated block.
  final bool lastReviewedByCreator;

  bool get generatedByAi => sourceMode != ContentSourceMode.manual;

  ContentProvenance copyWith({
    ContentSourceMode? sourceMode,
    bool? lastReviewedByCreator,
  }) {
    return ContentProvenance(
      sourceMode: sourceMode ?? this.sourceMode,
      lastReviewedByCreator:
          lastReviewedByCreator ?? this.lastReviewedByCreator,
    );
  }
}

// -----------------------------------------------------------------------------
// Multilingual explanations (extend with more keys later; UI picks one locale)
// -----------------------------------------------------------------------------

/// Optional learner-facing meanings (`en`, `my`, …). Extensible via [byLanguage].
class LocalizedMeanings {
  const LocalizedMeanings({
    this.en,
    this.my,
    this.byLanguage = const {},
  });

  /// English support meaning (optional).
  final String? en;

  /// Source-language support meaning (optional; stored as `my` for legacy/schema).
  final String? my;

  /// Additional BCP-47-ish codes for future locales.
  final Map<String, String> byLanguage;

  Map<String, String> get asMap {
    return {
      if (en != null && en!.trim().isNotEmpty) 'en': en!.trim(),
      if (my != null && my!.trim().isNotEmpty) 'my': my!.trim(),
      ...{for (final e in byLanguage.entries) e.key: e.value},
    };
  }

  LocalizedMeanings copyWith({
    String? en,
    String? my,
    Map<String, String>? byLanguage,
  }) {
    return LocalizedMeanings(
      en: en ?? this.en,
      my: my ?? this.my,
      byLanguage: byLanguage ?? Map.from(this.byLanguage),
    );
  }

  /// V1 helper: merge dialog input with existing [byLanguage] keys.
  static LocalizedMeanings? layerFromEnMy({
    required String enRaw,
    required String myRaw,
    LocalizedMeanings? preserveExtrasFrom,
  }) {
    final en = enRaw.trim();
    final my = myRaw.trim();
    final extra = Map<String, String>.from(preserveExtrasFrom?.byLanguage ?? {});
    if (en.isEmpty && my.isEmpty && extra.isEmpty) return null;
    return LocalizedMeanings(
      en: en.isEmpty ? null : en,
      my: my.isEmpty ? null : my,
      byLanguage: extra,
    );
  }
}

// -----------------------------------------------------------------------------
// Story core: sentences
// -----------------------------------------------------------------------------

class StorySentenceItem {
  StorySentenceItem({
    required this.id,
    required this.storyId,
    required this.orderIndex,
    required this.japaneseText,
    this.reading,
    this.furiganaSpans = const [],
    this.meanings,
    this.audioStartMs,
    this.audioEndMs,
    this.provenance,
  });

  final String id;
  final String storyId;
  final int orderIndex;

  /// Primary Japanese sentence (required for V1 validity).
  final String japaneseText;

  /// Optional furigana / reading line.
  ///
  /// Legacy V1 field (sentence-level). New furigana is stored as [furiganaSpans]
  /// attached to specific text ranges.
  final String? reading;

  /// Inline furigana annotations attached to substrings of [japaneseText].
  ///
  /// Each span is half-open \([start], [end]) in UTF-16 code unit indices.
  final List<FuriganaSpan> furiganaSpans;

  /// Optional support meanings ([LocalizedMeanings.en] / source via [LocalizedMeanings.my], …).
  final LocalizedMeanings? meanings;
  final int? audioStartMs;
  final int? audioEndMs;
  final ContentProvenance? provenance;

  bool get isValidV1 => japaneseText.trim().isNotEmpty;

  /// Short label for creator preview: translation availability (V1).
  String get supportMeaningsSummaryV1 {
    final m = meanings;
    if (m == null) return 'No translation';
    final hasEn = m.en != null && m.en!.trim().isNotEmpty;
    final hasSource = m.my != null && m.my!.trim().isNotEmpty;
    if (hasEn && hasSource) return 'Source + English';
    if (hasEn) return 'English';
    if (hasSource) return 'Source';
    return 'No translation';
  }

  StorySentenceItem copyWith({
    String? id,
    String? storyId,
    int? orderIndex,
    String? japaneseText,
    String? reading,
    bool clearReading = false,
    List<FuriganaSpan>? furiganaSpans,
    bool clearFuriganaSpans = false,
    LocalizedMeanings? meanings,
    bool clearMeanings = false,
    int? audioStartMs,
    int? audioEndMs,
    ContentProvenance? provenance,
  }) {
    return StorySentenceItem(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      orderIndex: orderIndex ?? this.orderIndex,
      japaneseText: japaneseText ?? this.japaneseText,
      reading: clearReading ? null : (reading ?? this.reading),
      furiganaSpans: clearFuriganaSpans
          ? const []
          : (furiganaSpans ?? List<FuriganaSpan>.from(this.furiganaSpans)),
      meanings: clearMeanings ? null : (meanings ?? this.meanings),
      audioStartMs: audioStartMs ?? this.audioStartMs,
      audioEndMs: audioEndMs ?? this.audioEndMs,
      provenance: provenance ?? this.provenance,
    );
  }
}

class FuriganaSpan {
  const FuriganaSpan({
    required this.start,
    required this.end,
    required this.reading,
  });

  final int start;
  final int end;
  final String reading;

  bool get isValid =>
      start >= 0 && end > start && reading.trim().isNotEmpty;
}

/// V1: optional reading for a vocab pick from story text — only when unambiguous.
///
/// Returns a reading when [selectedTerm] **exactly equals** either:
/// - [StorySentenceItem.japaneseText] and a non-empty legacy [StorySentenceItem.reading], or
/// - the substring of [StorySentenceItem.japaneseText] covered by a valid [FuriganaSpan].
///
/// If more than one distinct reading could apply, returns `null` (do not guess).
String? readingForVocabSelectionFromDraft({
  required List<StorySentenceItem> sentences,
  required String selectedTerm,
}) {
  final term = selectedTerm.trim();
  if (term.isEmpty) return null;

  final readings = <String>{};
  for (final s in sentences) {
    final jt = s.japaneseText;
    if (jt == term) {
      final legacy = s.reading?.trim();
      if (legacy != null && legacy.isNotEmpty) {
        readings.add(legacy);
      }
    }
    for (final span in s.furiganaSpans) {
      if (!span.isValid) continue;
      if (span.start < 0 || span.end > jt.length) continue;
      final seg = jt.substring(span.start, span.end);
      if (seg == term) {
        readings.add(span.reading.trim());
      }
    }
  }
  if (readings.length == 1) return readings.first;
  return null;
}

// -----------------------------------------------------------------------------
// Learn layers (separate payloads; status lives in [CreatorStoryV1.moduleWorkflowStatuses])
// -----------------------------------------------------------------------------

enum VocabularyKanjiEntryType {
  vocabulary,
  kanji,
}

extension VocabularyKanjiEntryTypeLabels on VocabularyKanjiEntryType {
  String get displayLabel => switch (this) {
        VocabularyKanjiEntryType.vocabulary => 'Vocabulary',
        VocabularyKanjiEntryType.kanji => 'Kanji',
      };

  String get storageKey => switch (this) {
        VocabularyKanjiEntryType.vocabulary => 'vocabulary',
        VocabularyKanjiEntryType.kanji => 'kanji',
      };

  static VocabularyKanjiEntryType fromStorageKey(String? k) {
    return switch ((k ?? '').trim()) {
      'kanji' => VocabularyKanjiEntryType.kanji,
      _ => VocabularyKanjiEntryType.vocabulary,
    };
  }
}

/// One paired example block: source-language sentence + English (creator V1).
class VocabularyExamplePair {
  const VocabularyExamplePair({
    this.sourceExample = '',
    this.englishExample = '',
  });

  final String sourceExample;
  final String englishExample;

  VocabularyExamplePair copyWith({
    String? sourceExample,
    String? englishExample,
  }) {
    return VocabularyExamplePair(
      sourceExample: sourceExample ?? this.sourceExample,
      englishExample: englishExample ?? this.englishExample,
    );
  }
}

class VocabularyKanjiEntry {
  VocabularyKanjiEntry({
    required this.id,
    required this.termJapanese,
    this.type = VocabularyKanjiEntryType.vocabulary,
    this.reading,
    this.glosses,
    this.exampleSentence,
    this.exampleMeanings,
    this.examplePairs = const [],
    this.provenance,
  });

  final String id;
  final String termJapanese;
  final VocabularyKanjiEntryType type;
  final String? reading;
  final LocalizedMeanings? glosses;
  final String? exampleSentence;
  final LocalizedMeanings? exampleMeanings;

  /// Up to three paired example blocks (source sentence + English).
  ///
  /// [exampleSentence] / [exampleMeanings] remain as merged legacy mirrors for
  /// older readers; prefer [examplePairs] in new code.
  final List<VocabularyExamplePair> examplePairs;
  final ContentProvenance? provenance;

  bool get isValidV1 => termJapanese.trim().isNotEmpty;

  /// Example rows for editor UI (max 3), including migration from legacy fields.
  List<VocabularyExamplePair> get effectiveExamplePairs {
    if (examplePairs.isNotEmpty) {
      return List<VocabularyExamplePair>.from(examplePairs.take(3));
    }
    final jp = exampleSentence?.trim() ?? '';
    final en = exampleMeanings?.en?.trim() ?? '';
    final my = exampleMeanings?.my?.trim() ?? '';
    if (jp.isEmpty && en.isEmpty && my.isEmpty) return const [];
    return [
      VocabularyExamplePair(
        sourceExample: exampleSentence ?? '',
        englishExample: en.isNotEmpty ? en : my,
      ),
    ];
  }

  VocabularyKanjiEntry copyWith({
    String? id,
    String? termJapanese,
    VocabularyKanjiEntryType? type,
    String? reading,
    bool clearReading = false,
    LocalizedMeanings? glosses,
    bool clearGlosses = false,
    String? exampleSentence,
    bool clearExampleSentence = false,
    LocalizedMeanings? exampleMeanings,
    bool clearExampleMeanings = false,
    List<VocabularyExamplePair>? examplePairs,
    ContentProvenance? provenance,
  }) {
    return VocabularyKanjiEntry(
      id: id ?? this.id,
      termJapanese: termJapanese ?? this.termJapanese,
      type: type ?? this.type,
      reading: clearReading ? null : (reading ?? this.reading),
      glosses: clearGlosses ? null : (glosses ?? this.glosses),
      exampleSentence:
          clearExampleSentence ? null : (exampleSentence ?? this.exampleSentence),
      exampleMeanings:
          clearExampleMeanings ? null : (exampleMeanings ?? this.exampleMeanings),
      examplePairs: examplePairs ?? this.examplePairs,
      provenance: provenance ?? this.provenance,
    );
  }
}

class GrammarEntry {
  GrammarEntry({
    required this.id,
    required this.headline,
    this.form,
    this.meanings,
    this.usage,
    this.examples = const [],
    this.mistakeWrong,
    this.mistakeCorrect,
    this.relatedNote,
    this.provenance,
  });

  final String id;
  final String headline;

  /// Compact form line (optional), e.g. `N + について`.
  final String? form;

  /// Optional meanings (EN/MY).
  final LocalizedMeanings? meanings;

  /// Optional usage / when-to-use note (EN/MY).
  final LocalizedMeanings? usage;

  /// Up to a few examples (V1: manual, lightweight).
  final List<GrammarExample> examples;

  /// Optional common mistake pair.
  final String? mistakeWrong;
  final String? mistakeCorrect;

  /// Optional related note (EN/MY).
  final LocalizedMeanings? relatedNote;

  final ContentProvenance? provenance;

  bool get isValidV1 => headline.trim().isNotEmpty;

  GrammarEntry copyWith({
    String? id,
    String? headline,
    String? form,
    bool clearForm = false,
    LocalizedMeanings? meanings,
    bool clearMeanings = false,
    LocalizedMeanings? usage,
    bool clearUsage = false,
    List<GrammarExample>? examples,
    String? mistakeWrong,
    bool clearMistakeWrong = false,
    String? mistakeCorrect,
    bool clearMistakeCorrect = false,
    LocalizedMeanings? relatedNote,
    bool clearRelatedNote = false,
    ContentProvenance? provenance,
  }) {
    return GrammarEntry(
      id: id ?? this.id,
      headline: headline ?? this.headline,
      form: clearForm ? null : (form ?? this.form),
      meanings: clearMeanings ? null : (meanings ?? this.meanings),
      usage: clearUsage ? null : (usage ?? this.usage),
      examples: examples ?? List.from(this.examples),
      mistakeWrong: clearMistakeWrong ? null : (mistakeWrong ?? this.mistakeWrong),
      mistakeCorrect:
          clearMistakeCorrect ? null : (mistakeCorrect ?? this.mistakeCorrect),
      relatedNote: clearRelatedNote ? null : (relatedNote ?? this.relatedNote),
      provenance: provenance ?? this.provenance,
    );
  }
}

class GrammarExample {
  const GrammarExample({
    required this.japanese,
    this.meanings,
  });

  final String japanese;
  final LocalizedMeanings? meanings;

  bool get isEmptyV1 =>
      japanese.trim().isEmpty && (meanings == null || meanings!.asMap.isEmpty);
}

class QuizEntry {
  QuizEntry({
    required this.id,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanations,
    this.sourceNote,
    this.provenance,
  }) : assert(options.length == 4, 'V1 quiz requires 4 options');

  final String id;

  final CreatorQuizCategory category;
  final String prompt;

  /// Exactly 4 items: A, B, C, D.
  final List<String> options;

  /// 0..3
  final int correctIndex;

  /// Optional explanation (EN/MY).
  final LocalizedMeanings? explanations;

  /// Optional source sentence or author note.
  final String? sourceNote;

  final ContentProvenance? provenance;

  bool get isValidV1 {
    if (prompt.trim().isEmpty) return false;
    if (options.length != 4) return false;
    if (correctIndex < 0 || correctIndex > 3) return false;
    for (final o in options) {
      if (o.trim().isEmpty) return false;
    }
    return true;
  }

  QuizEntry copyWith({
    String? id,
    CreatorQuizCategory? category,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    LocalizedMeanings? explanations,
    bool clearExplanations = false,
    String? sourceNote,
    bool clearSourceNote = false,
    ContentProvenance? provenance,
  }) {
    return QuizEntry(
      id: id ?? this.id,
      category: category ?? this.category,
      prompt: prompt ?? this.prompt,
      options: options ?? List.from(this.options),
      correctIndex: correctIndex ?? this.correctIndex,
      explanations: clearExplanations ? null : (explanations ?? this.explanations),
      sourceNote: clearSourceNote ? null : (sourceNote ?? this.sourceNote),
      provenance: provenance ?? this.provenance,
    );
  }
}

enum CreatorQuizCategory {
  vocabulary,
  kanji,
  grammar,
  sampleSentence,
}

extension CreatorQuizCategoryLabels on CreatorQuizCategory {
  String get displayLabel => switch (this) {
        CreatorQuizCategory.vocabulary => 'Vocabulary',
        CreatorQuizCategory.kanji => 'Kanji',
        CreatorQuizCategory.grammar => 'Grammar',
        CreatorQuizCategory.sampleSentence => 'Sentence',
      };

  String get storageKey => switch (this) {
        CreatorQuizCategory.vocabulary => 'vocabulary',
        CreatorQuizCategory.kanji => 'kanji',
        CreatorQuizCategory.grammar => 'grammar',
        CreatorQuizCategory.sampleSentence => 'sample_sentence',
      };

  static CreatorQuizCategory fromStorageKey(String? k) {
    return switch ((k ?? '').trim()) {
      'kanji' => CreatorQuizCategory.kanji,
      'grammar' => CreatorQuizCategory.grammar,
      'sample_sentence' => CreatorQuizCategory.sampleSentence,
      _ => CreatorQuizCategory.vocabulary,
    };
  }
}

class StoryAudioAsset {
  StoryAudioAsset({
    required this.id,
    this.sourceUrl,
    this.localFileName,
    this.localPath,
    this.localSizeBytes,
    this.localExtension,
    this.displayName,
    this.durationSeconds,
    this.provenance,
  });

  final String id;
  final String? sourceUrl;
  /// Creator-picked local file metadata for V1 upload-first flow.
  ///
  /// - [localFileName] is the primary creator-visible identifier.
  /// - [localPath] is best-effort (may be null on web).
  final String? localFileName;
  final String? localPath;
  final int? localSizeBytes;
  final String? localExtension;
  final String? displayName;

  /// Optional duration (V1: manual input). Keep null if unknown.
  final int? durationSeconds;
  final ContentProvenance? provenance;

  bool get isValidV1 {
    final urlOk = sourceUrl != null && sourceUrl!.trim().isNotEmpty;
    final nameOk = localFileName != null && localFileName!.trim().isNotEmpty;
    final pathOk = localPath != null && localPath!.trim().isNotEmpty;
    return urlOk || nameOk || pathOk;
  }

  bool get hasUploadedSourceUrl {
    final s = (sourceUrl ?? '').trim();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  StoryAudioAsset copyWith({
    String? id,
    String? sourceUrl,
    bool clearSourceUrl = false,
    String? localFileName,
    bool clearLocalFileName = false,
    String? localPath,
    bool clearLocalPath = false,
    int? localSizeBytes,
    bool clearLocalSizeBytes = false,
    String? localExtension,
    bool clearLocalExtension = false,
    String? displayName,
    bool clearDisplayName = false,
    int? durationSeconds,
    bool clearDurationSeconds = false,
    ContentProvenance? provenance,
  }) {
    return StoryAudioAsset(
      id: id ?? this.id,
      sourceUrl: clearSourceUrl ? null : (sourceUrl ?? this.sourceUrl),
      localFileName:
          clearLocalFileName ? null : (localFileName ?? this.localFileName),
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      localSizeBytes:
          clearLocalSizeBytes ? null : (localSizeBytes ?? this.localSizeBytes),
      localExtension:
          clearLocalExtension ? null : (localExtension ?? this.localExtension),
      displayName:
          clearDisplayName ? null : (displayName ?? this.displayName),
      durationSeconds: clearDurationSeconds
          ? null
          : (durationSeconds ?? this.durationSeconds),
      provenance: provenance ?? this.provenance,
    );
  }
}

class VocabularyKanjiLayer {
  const VocabularyKanjiLayer({this.entries = const []});

  final List<VocabularyKanjiEntry> entries;
}

class GrammarLayer {
  const GrammarLayer({this.entries = const []});

  final List<GrammarEntry> entries;
}

class QuizLayer {
  const QuizLayer({this.entries = const []});

  final List<QuizEntry> entries;
}

class AudioLayer {
  const AudioLayer({this.storyAudio});

  /// Single story-level track for V1 “audio module complete” rule.
  final StoryAudioAsset? storyAudio;
}

// -----------------------------------------------------------------------------
// Story basics
// -----------------------------------------------------------------------------

class StoryBasics {
  StoryBasics({
    required this.storyId,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.promptSourceNote,
    this.targetDurationBandKey,
    this.coverImageUrl,
    required this.creatorOwnerId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String storyId;
  final String title;
  final String category;
  final String level;
  final String description;
  final String promptSourceNote;
  /// V1 intended duration band storage key (e.g. `3_5`, `5_7`, `7_9`).
  ///
  /// This is the canonical duration signal for completion/readiness thresholds.
  final String? targetDurationBandKey;
  final String? coverImageUrl;
  final String creatorOwnerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When [replaceCoverImage] is true, [coverImageUrl] replaces the cover (use `null` to clear).
  /// When false, [coverImageUrl] is ignored and the previous cover is kept.
  StoryBasics copyWith({
    String? storyId,
    String? title,
    String? category,
    String? level,
    String? description,
    String? promptSourceNote,
    String? targetDurationBandKey,
    bool clearTargetDurationBandKey = false,
    String? coverImageUrl,
    bool replaceCoverImage = false,
    String? creatorOwnerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoryBasics(
      storyId: storyId ?? this.storyId,
      title: title ?? this.title,
      category: category ?? this.category,
      level: level ?? this.level,
      description: description ?? this.description,
      promptSourceNote: promptSourceNote ?? this.promptSourceNote,
      targetDurationBandKey: clearTargetDurationBandKey
          ? null
          : (targetDurationBandKey ?? this.targetDurationBandKey),
      coverImageUrl: replaceCoverImage
          ? coverImageUrl
          : (coverImageUrl ?? this.coverImageUrl),
      creatorOwnerId: creatorOwnerId ?? this.creatorOwnerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// -----------------------------------------------------------------------------
// Aggregate creator story (V1)
// -----------------------------------------------------------------------------

class CreatorStoryV1 {
  CreatorStoryV1({
    required this.basics,
    required this.sentences,
    required this.vocabularyKanji,
    required this.grammar,
    required this.quiz,
    required this.audio,
    required this.publishState,
    required Map<LearnModuleId, LearnModuleTaskStatus> moduleWorkflowStatuses,
  }) : moduleWorkflowStatuses =
            Map<LearnModuleId, LearnModuleTaskStatus>.from(moduleWorkflowStatuses);

  final StoryBasics basics;
  final List<StorySentenceItem> sentences;
  final VocabularyKanjiLayer vocabularyKanji;
  final GrammarLayer grammar;
  final QuizLayer quiz;
  final AudioLayer audio;
  final StoryPublishState publishState;
  final Map<LearnModuleId, LearnModuleTaskStatus> moduleWorkflowStatuses;

  static final _uuid = Uuid();

  factory CreatorStoryV1.empty({String creatorOwnerId = ''}) {
    final id = _uuid.v4();
    final now = DateTime.now();
    final modules = {
      for (final m in LearnModuleId.values) m: LearnModuleTaskStatus.notStarted,
    };
    return CreatorStoryV1(
      basics: StoryBasics(
        storyId: id,
        title: '',
        category: '',
        level: '',
        description: '',
        promptSourceNote: '',
        coverImageUrl: null,
        creatorOwnerId: creatorOwnerId,
        createdAt: now,
        updatedAt: now,
      ),
      sentences: const [],
      vocabularyKanji: const VocabularyKanjiLayer(),
      grammar: const GrammarLayer(),
      quiz: const QuizLayer(),
      audio: const AudioLayer(),
      publishState: StoryPublishState.draft,
      moduleWorkflowStatuses: modules,
    );
  }

  // ——— Convenience (keeps creator screens concise) ———

  String get id => basics.storyId;
  String get title => basics.title;
  String get category => basics.category;
  String get level => basics.level;
  String get description => basics.description;
  String get promptSourceNote => basics.promptSourceNote;

  /// Line-joined Japanese for the simple sentence editor (round-trip).
  String get sentencesPlaintextDisplay =>
      sentences.map((s) => s.japaneseText).join('\n');

  Map<LearnModuleId, LearnModuleTaskStatus> get moduleStatuses =>
      moduleWorkflowStatuses;

  /// Step 1: all basic fields present (includes description).
  bool get isBasicsComplete =>
      title.trim().isNotEmpty &&
      category.trim().isNotEmpty &&
      level.trim().isNotEmpty &&
      description.trim().isNotEmpty;

  /// Core ready for **Reading Only** (modules optional).
  bool get isStoryCoreReadyForReading =>
      isBasicsComplete && sentences.any((s) => s.isValidV1);

  /// Alias for workflow copy / older names.
  bool get isCoreComplete => isStoryCoreReadyForReading;

  bool get canPublishReadingOnly => isStoryCoreReadyForReading;

  /// Creator-marked “done” (UI); can diverge from data until they align.
  bool get allLearnModulesMarkedCompleted => LearnModuleId.values.every(
        (id) => moduleWorkflowStatuses[id] == LearnModuleTaskStatus.completed,
      );

  CreatorStoryV1 copyWith({
    StoryBasics? basics,
    List<StorySentenceItem>? sentences,
    VocabularyKanjiLayer? vocabularyKanji,
    GrammarLayer? grammar,
    QuizLayer? quiz,
    AudioLayer? audio,
    StoryPublishState? publishState,
    Map<LearnModuleId, LearnModuleTaskStatus>? moduleWorkflowStatuses,
  }) {
    return CreatorStoryV1(
      basics: basics ?? this.basics,
      sentences: sentences ?? List.from(this.sentences),
      vocabularyKanji: vocabularyKanji ?? this.vocabularyKanji,
      grammar: grammar ?? this.grammar,
      quiz: quiz ?? this.quiz,
      audio: audio ?? this.audio,
      publishState: publishState ?? this.publishState,
      moduleWorkflowStatuses:
          moduleWorkflowStatuses ?? Map.from(this.moduleWorkflowStatuses),
    );
  }
}

// -----------------------------------------------------------------------------
// Plaintext import (V1 sentence editor)
// -----------------------------------------------------------------------------

/// Trimmed non-empty lines as produced by [storySentencesFromPlaintext].
List<String> storyPlaintextNonEmptyLines(String plain) {
  return plain
      .split(RegExp(r'\r?\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// True when [plain] yields at least one [StorySentenceItem] with [StorySentenceItem.isValidV1].
bool storyPlaintextHasValidSentence(String plain) =>
    storyPlaintextNonEmptyLines(plain).isNotEmpty;

List<StorySentenceItem> storySentencesFromPlaintext({
  required String storyId,
  required String plain,
  ContentProvenance provenance = const ContentProvenance(),
}) {
  return storySentencesFromPlaintextMerge(
    storyId: storyId,
    plain: plain,
    previous: const [],
    defaultProvenance: provenance,
  );
}

/// Parses [plain] into sentences, reusing prior rows when [japaneseText] matches
/// so optional fields ([reading], [meanings], …) survive plaintext edits/reorders.
List<StorySentenceItem> storySentencesFromPlaintextMerge({
  required String storyId,
  required String plain,
  List<StorySentenceItem> previous = const [],
  ContentProvenance defaultProvenance = const ContentProvenance(),
}) {
  final lines = storyPlaintextNonEmptyLines(plain);
  final pool = List<StorySentenceItem>.from(previous);
  final uuid = CreatorStoryV1._uuid;
  return [
    for (var i = 0; i < lines.length; i++)
      () {
        final text = lines[i];
        final j = pool.indexWhere((s) => s.japaneseText == text);
        if (j >= 0) {
          final old = pool.removeAt(j);
          return old.copyWith(
            storyId: storyId,
            orderIndex: i,
            japaneseText: text,
          );
        }
        return StorySentenceItem(
          id: uuid.v4(),
          storyId: storyId,
          orderIndex: i,
          japaneseText: text,
          provenance: defaultProvenance,
        );
      }(),
  ];
}
