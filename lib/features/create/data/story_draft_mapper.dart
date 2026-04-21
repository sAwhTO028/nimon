import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/dto/story_draft_processing_item_dto.dart';
import 'package:nimon/features/create/story_v1_model.dart';

StoryPublishState _publishStateFromKey(String? k) {
  return switch ((k ?? '').trim()) {
    'reading_only_published' => StoryPublishState.readingOnlyPublished,
    'full_learn_published' => StoryPublishState.fullLearnPublished,
    _ => StoryPublishState.draft,
  };
}

LearnModuleTaskStatus _moduleTaskStatusFromKey(String? k) {
  return switch ((k ?? '').trim()) {
    'in_progress' => LearnModuleTaskStatus.inProgress,
    'completed' => LearnModuleTaskStatus.completed,
    _ => LearnModuleTaskStatus.notStarted,
  };
}

/// Maps between [CreatorStoryV1] and wire-oriented DTOs. No I/O.
abstract final class StoryDraftMapper {
  StoryDraftMapper._();

  // ---------------------------------------------------------------------------
  // Domain -> DTO
  // ---------------------------------------------------------------------------

  /// Full mapping; includes local-only audio file fields unless [stripLocalAudioFields].
  static StoryDraftDto fromDomain(
    CreatorStoryV1 story, {
    bool stripLocalAudioFields = false,
  }) {
    return StoryDraftDto(
      draftId: story.id,
      schemaVersion: 1,
      ownerId: story.basics.creatorOwnerId.isEmpty
          ? null
          : story.basics.creatorOwnerId,
      createdAt: story.basics.createdAt.toUtc().toIso8601String(),
      updatedAt: story.basics.updatedAt.toUtc().toIso8601String(),
      basics: _basicsToDto(story.basics),
      sentences: [for (final s in story.sentences) _sentenceToDto(s)],
      vocabularyKanji: VocabularyKanjiLayerDto(
        entries: [
          for (final e in story.vocabularyKanji.entries) _vocabEntryToDto(e),
        ],
      ),
      grammar: GrammarLayerDto(
        entries: [
          for (final e in story.grammar.entries) _grammarEntryToDto(e),
        ],
      ),
      quiz: QuizLayerDto(
        entries: [for (final e in story.quiz.entries) _quizEntryToDto(e)],
      ),
      audio: AudioLayerDto(
        storyAudio: _audioToDto(story.audio.storyAudio,
            stripLocal: stripLocalAudioFields),
      ),
      publishState: story.publishState.storageKey,
      moduleWorkflowStatuses: {
        for (final e in story.moduleWorkflowStatuses.entries)
          e.key.storageKey: e.value.storageKey,
      },
    );
  }

  /// Payload suitable for future HTTP upload (strips device-only audio metadata).
  static StoryDraftDto fromDomainRemoteSafe(CreatorStoryV1 story) =>
      fromDomain(story, stripLocalAudioFields: true);

  /// Lightweight processing list row (caller supplies readiness copy if needed).
  static StoryDraftProcessingItemDto processingItemFromDomain(
    CreatorStoryV1 story, {
    String? readinessSummary,
    String? primaryActionHint,
  }) {
    final t = story.title.trim();
    return StoryDraftProcessingItemDto(
      draftId: story.id,
      title: t.isEmpty ? 'Untitled draft' : t,
      updatedAt: story.basics.updatedAt.toUtc().toIso8601String(),
      publishState: story.publishState.storageKey,
      readinessSummary: readinessSummary,
      primaryActionHint: primaryActionHint,
    );
  }

  // ---------------------------------------------------------------------------
  // DTO -> Domain
  // ---------------------------------------------------------------------------

  static CreatorStoryV1 toDomain(StoryDraftDto dto) {
    final basics = _basicsFromDto(dto.basics);
    final sentences = <StorySentenceItem>[
      for (final s in dto.sentences) _sentenceFromDto(s),
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final vocab = VocabularyKanjiLayer(
      entries: [
        for (final e in dto.vocabularyKanji.entries) _vocabEntryFromDto(e),
      ],
    );
    final grammar = GrammarLayer(
      entries: [for (final e in dto.grammar.entries) _grammarEntryFromDto(e)],
    );
    final quiz = QuizLayer(
      entries: [for (final e in dto.quiz.entries) _quizEntryFromDto(e)],
    );
    final audio = AudioLayer(
      storyAudio: _audioFromDto(dto.audio.storyAudio),
    );

    final moduleStatuses = <LearnModuleId, LearnModuleTaskStatus>{
      for (final id in LearnModuleId.values)
        id: _moduleTaskStatusFromKey(
          dto.moduleWorkflowStatuses[id.storageKey],
        ),
    };

    return CreatorStoryV1(
      basics: basics,
      sentences: sentences,
      vocabularyKanji: vocab,
      grammar: grammar,
      quiz: quiz,
      audio: audio,
      publishState: _publishStateFromKey(dto.publishState),
      moduleWorkflowStatuses: moduleStatuses,
    );
  }

  static StoryDraftBasicsDto _basicsToDto(StoryBasics b) {
    return StoryDraftBasicsDto(
      storyId: b.storyId,
      ownerId: b.creatorOwnerId,
      title: b.title,
      category: b.category,
      level: b.level,
      description: b.description,
      promptSourceNote: b.promptSourceNote,
      targetDurationBandKey: b.targetDurationBandKey,
      coverImageUrl: b.coverImageUrl,
      createdAt: b.createdAt.toUtc().toIso8601String(),
      updatedAt: b.updatedAt.toUtc().toIso8601String(),
    );
  }

  static StoryBasics _basicsFromDto(StoryDraftBasicsDto b) {
    return StoryBasics(
      storyId: b.storyId,
      title: b.title,
      category: b.category,
      level: b.level,
      description: b.description,
      promptSourceNote: b.promptSourceNote,
      targetDurationBandKey: b.targetDurationBandKey,
      coverImageUrl: b.coverImageUrl,
      creatorOwnerId: b.ownerId,
      createdAt: _parseIso(b.createdAt),
      updatedAt: _parseIso(b.updatedAt),
    );
  }

  static StorySentenceDto _sentenceToDto(StorySentenceItem s) {
    return StorySentenceDto(
      id: s.id,
      storyId: s.storyId,
      orderIndex: s.orderIndex,
      japaneseText: s.japaneseText,
      reading: s.reading,
      furiganaSpans: [
        for (final f in s.furiganaSpans)
          FuriganaSpanDto(start: f.start, end: f.end, reading: f.reading),
      ],
      meanings: s.meanings == null ? null : _meaningsToDto(s.meanings!),
      audioStartMs: s.audioStartMs,
      audioEndMs: s.audioEndMs,
      provenance: s.provenance == null ? null : _provToDto(s.provenance!),
    );
  }

  static StorySentenceItem _sentenceFromDto(StorySentenceDto s) {
    return StorySentenceItem(
      id: s.id,
      storyId: s.storyId,
      orderIndex: s.orderIndex,
      japaneseText: s.japaneseText,
      reading: s.reading,
      furiganaSpans: [
        for (final f in s.furiganaSpans)
          FuriganaSpan(
            start: f.start,
            end: f.end,
            reading: f.reading,
          ),
      ],
      meanings: s.meanings == null ? null : _meaningsFromDto(s.meanings!),
      audioStartMs: s.audioStartMs,
      audioEndMs: s.audioEndMs,
      provenance: s.provenance == null ? null : _provFromDto(s.provenance!),
    );
  }

  static LocalizedMeaningsDto _meaningsToDto(LocalizedMeanings m) {
    return LocalizedMeaningsDto(
      en: m.en,
      my: m.my,
      byLanguage: Map<String, String>.from(m.byLanguage),
    );
  }

  static LocalizedMeanings _meaningsFromDto(LocalizedMeaningsDto m) {
    return LocalizedMeanings(
      en: m.en,
      my: m.my,
      byLanguage: Map<String, String>.from(m.byLanguage),
    );
  }

  static ContentProvenanceDto _provToDto(ContentProvenance p) {
    return ContentProvenanceDto(
      sourceMode: p.sourceMode.name,
      lastReviewedByCreator: p.lastReviewedByCreator,
    );
  }

  static ContentProvenance _provFromDto(ContentProvenanceDto p) {
    return ContentProvenance(
      sourceMode: ContentSourceMode.values.firstWhere(
        (e) => e.name == p.sourceMode,
        orElse: () => ContentSourceMode.manual,
      ),
      lastReviewedByCreator: p.lastReviewedByCreator,
    );
  }

  static VocabularyKanjiEntryDto _vocabEntryToDto(VocabularyKanjiEntry e) {
    return VocabularyKanjiEntryDto(
      id: e.id,
      termJapanese: e.termJapanese,
      type: e.type.storageKey,
      reading: e.reading,
      glosses: e.glosses == null ? null : _meaningsToDto(e.glosses!),
      exampleSentence: e.exampleSentence,
      exampleMeanings:
          e.exampleMeanings == null ? null : _meaningsToDto(e.exampleMeanings!),
      examplePairs: [
        for (final p in e.examplePairs)
          VocabularyExamplePairDto(
            source: p.sourceExample,
            english: p.englishExample,
          ),
      ],
      provenance: e.provenance == null ? null : _provToDto(e.provenance!),
    );
  }

  static VocabularyKanjiEntry _vocabEntryFromDto(VocabularyKanjiEntryDto e) {
    return VocabularyKanjiEntry(
      id: e.id,
      termJapanese: e.termJapanese,
      type: VocabularyKanjiEntryTypeLabels.fromStorageKey(e.type),
      reading: e.reading,
      glosses: e.glosses == null ? null : _meaningsFromDto(e.glosses!),
      exampleSentence: e.exampleSentence,
      exampleMeanings: e.exampleMeanings == null
          ? null
          : _meaningsFromDto(e.exampleMeanings!),
      examplePairs: [
        for (final p in e.examplePairs)
          VocabularyExamplePair(
            sourceExample: p.source,
            englishExample: p.english,
          ),
      ],
      provenance: e.provenance == null ? null : _provFromDto(e.provenance!),
    );
  }

  static GrammarEntryDto _grammarEntryToDto(GrammarEntry e) {
    return GrammarEntryDto(
      id: e.id,
      headline: e.headline,
      form: e.form,
      meanings: e.meanings == null ? null : _meaningsToDto(e.meanings!),
      usage: e.usage == null ? null : _meaningsToDto(e.usage!),
      examples: [
        for (final x in e.examples)
          GrammarExampleDto(
            japanese: x.japanese,
            meanings: x.meanings == null ? null : _meaningsToDto(x.meanings!),
          ),
      ],
      mistakeWrong: e.mistakeWrong,
      mistakeCorrect: e.mistakeCorrect,
      relatedNote:
          e.relatedNote == null ? null : _meaningsToDto(e.relatedNote!),
      provenance: e.provenance == null ? null : _provToDto(e.provenance!),
    );
  }

  static GrammarEntry _grammarEntryFromDto(GrammarEntryDto e) {
    return GrammarEntry(
      id: e.id,
      headline: e.headline,
      form: e.form,
      meanings: e.meanings == null ? null : _meaningsFromDto(e.meanings!),
      usage: e.usage == null ? null : _meaningsFromDto(e.usage!),
      examples: [
        for (final x in e.examples)
          GrammarExample(
            japanese: x.japanese,
            meanings: x.meanings == null ? null : _meaningsFromDto(x.meanings!),
          ),
      ],
      mistakeWrong: e.mistakeWrong,
      mistakeCorrect: e.mistakeCorrect,
      relatedNote:
          e.relatedNote == null ? null : _meaningsFromDto(e.relatedNote!),
      provenance: e.provenance == null ? null : _provFromDto(e.provenance!),
    );
  }

  static QuizEntryDto _quizEntryToDto(QuizEntry e) {
    return QuizEntryDto(
      id: e.id,
      category: e.category.storageKey,
      prompt: e.prompt,
      options: List<String>.from(e.options),
      correctIndex: e.correctIndex,
      explanations:
          e.explanations == null ? null : _meaningsToDto(e.explanations!),
      sourceNote: e.sourceNote,
      provenance: e.provenance == null ? null : _provToDto(e.provenance!),
    );
  }

  static QuizEntry _quizEntryFromDto(QuizEntryDto e) {
    final opts = _fourOptions(e.options);
    return QuizEntry(
      id: e.id,
      category: CreatorQuizCategoryLabels.fromStorageKey(e.category),
      prompt: e.prompt,
      options: opts,
      correctIndex: e.correctIndex.clamp(0, 3),
      explanations:
          e.explanations == null ? null : _meaningsFromDto(e.explanations!),
      sourceNote: e.sourceNote,
      provenance: e.provenance == null ? null : _provFromDto(e.provenance!),
    );
  }

  static StoryAudioDto? _audioToDto(StoryAudioAsset? a, {required bool stripLocal}) {
    if (a == null) return null;
    final remoteUrl = _remoteSourceUrl(a.sourceUrl);
    return StoryAudioDto(
      id: a.id,
      sourceUrl: stripLocal
          ? remoteUrl
          : a.sourceUrl,
      localFileName: stripLocal ? null : a.localFileName,
      localPath: stripLocal ? null : a.localPath,
      localSizeBytes: stripLocal ? null : a.localSizeBytes,
      localExtension: stripLocal ? null : a.localExtension,
      displayName: a.displayName,
      durationSeconds: a.durationSeconds,
      provenance: a.provenance == null ? null : _provToDto(a.provenance!),
    );
  }

  static String? _remoteSourceUrl(String? sourceUrl) {
    final t = (sourceUrl ?? '').trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return null;
  }

  static StoryAudioAsset? _audioFromDto(StoryAudioDto? d) {
    if (d == null) return null;
    return StoryAudioAsset(
      id: d.id,
      sourceUrl: d.sourceUrl,
      localFileName: d.localFileName,
      localPath: d.localPath,
      localSizeBytes: d.localSizeBytes,
      localExtension: d.localExtension,
      displayName: d.displayName,
      durationSeconds: d.durationSeconds,
      provenance: d.provenance == null ? null : _provFromDto(d.provenance!),
    );
  }

  static List<String> _fourOptions(List<String> o) {
    final out = List<String>.from(o.map((x) => x));
    while (out.length < 4) {
      out.add('');
    }
    return out.length > 4 ? out.sublist(0, 4) : out;
  }

  static DateTime _parseIso(String s) {
    return DateTime.tryParse(s)?.toLocal() ?? DateTime.now();
  }
}
