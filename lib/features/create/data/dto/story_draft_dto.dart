/// JSON-oriented DTOs for future draft sync / HTTP APIs.
/// Domain remains [CreatorStoryV1]; map via [StoryDraftMapper].

/// Server publish linkage and timestamps (GET / publish responses).
class PublishResponseDto {
  const PublishResponseDto({
    required this.draftId,
    required this.publishState,
    this.publishedMonoId,
    this.readingOnlyPublishedAt,
    this.fullLearnPublishedAt,
    required this.updatedAt,
  });

  final String draftId;

  /// Same string keys as [StoryPublishState.storageKey].
  final String publishState;
  final String? publishedMonoId;
  final String? readingOnlyPublishedAt;
  final String? fullLearnPublishedAt;
  final String updatedAt;
}

/// Full draft payload for PUT/GET-style exchanges (aligned with local JSON + API plan).
class StoryDraftDto {
  const StoryDraftDto({
    required this.draftId,
    this.schemaVersion = 1,
    this.ownerId,
    this.createdAt,
    this.updatedAt,
    this.publishedMonoId,
    this.readingOnlyPublishedAt,
    this.fullLearnPublishedAt,
    this.hasUnpublishedCoreChanges,
    this.etag,
    required this.basics,
    required this.sentences,
    required this.vocabularyKanji,
    required this.grammar,
    required this.quiz,
    required this.audio,
    required this.publishState,
    required this.moduleWorkflowStatuses,
  });

  /// Canonical id (equals [StoryDraftBasicsDto.storyId]).
  final String draftId;
  final int schemaVersion;

  /// Server owner; omitted on many writes (token-derived). Maps from [StoryBasics.creatorOwnerId].
  final String? ownerId;

  final String? createdAt;
  final String? updatedAt;

  final String? publishedMonoId;
  final String? readingOnlyPublishedAt;
  final String? fullLearnPublishedAt;

  /// Server-side “staging” flag when linked to a published mono (`null` if omitted).
  final bool? hasUnpublishedCoreChanges;

  /// Optional HTTP ETag mirror for concurrency.
  final String? etag;

  final StoryDraftBasicsDto basics;
  final List<StorySentenceDto> sentences;
  final VocabularyKanjiLayerDto vocabularyKanji;
  final GrammarLayerDto grammar;
  final QuizLayerDto quiz;
  final AudioLayerDto audio;

  /// [StoryPublishState.storageKey] value.
  final String publishState;

  /// Keys: [LearnModuleId.storageKey] → [LearnModuleTaskStatus.storageKey].
  final Map<String, String> moduleWorkflowStatuses;
}

class StoryDraftBasicsDto {
  const StoryDraftBasicsDto({
    required this.storyId,
    required this.ownerId,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.promptSourceNote,
    this.targetDurationBandKey,
    this.coverImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String storyId;
  final String ownerId;
  final String title;
  final String category;
  final String level;
  final String description;
  final String promptSourceNote;
  final String? targetDurationBandKey;
  final String? coverImageUrl;
  final String createdAt;
  final String updatedAt;
}

class LocalizedMeaningsDto {
  const LocalizedMeaningsDto({
    this.en,
    this.my,
    this.byLanguage = const {},
  });

  final String? en;
  final String? my;
  final Map<String, String> byLanguage;
}

class ContentProvenanceDto {
  const ContentProvenanceDto({
    required this.sourceMode,
    required this.lastReviewedByCreator,
  });

  final String sourceMode;
  final bool lastReviewedByCreator;
}

class FuriganaSpanDto {
  const FuriganaSpanDto({
    required this.start,
    required this.end,
    required this.reading,
  });

  final int start;
  final int end;
  final String reading;
}

class StorySentenceDto {
  const StorySentenceDto({
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
  final String japaneseText;
  final String? reading;
  final List<FuriganaSpanDto> furiganaSpans;
  final LocalizedMeaningsDto? meanings;
  final int? audioStartMs;
  final int? audioEndMs;
  final ContentProvenanceDto? provenance;
}

class VocabularyExamplePairDto {
  const VocabularyExamplePairDto({
    required this.source,
    required this.english,
  });

  final String source;
  final String english;
}

class VocabularyKanjiEntryDto {
  const VocabularyKanjiEntryDto({
    required this.id,
    required this.termJapanese,
    required this.type,
    this.reading,
    this.glosses,
    this.exampleSentence,
    this.exampleMeanings,
    this.examplePairs = const [],
    this.provenance,
  });

  final String id;
  final String termJapanese;

  /// [VocabularyKanjiEntryType.storageKey].
  final String type;
  final String? reading;
  final LocalizedMeaningsDto? glosses;
  final String? exampleSentence;
  final LocalizedMeaningsDto? exampleMeanings;
  final List<VocabularyExamplePairDto> examplePairs;
  final ContentProvenanceDto? provenance;
}

class VocabularyKanjiLayerDto {
  const VocabularyKanjiLayerDto({this.entries = const []});

  final List<VocabularyKanjiEntryDto> entries;
}

class GrammarExampleDto {
  const GrammarExampleDto({
    required this.japanese,
    this.meanings,
  });

  final String japanese;
  final LocalizedMeaningsDto? meanings;
}

class GrammarEntryDto {
  const GrammarEntryDto({
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
  final String? form;
  final LocalizedMeaningsDto? meanings;
  final LocalizedMeaningsDto? usage;
  final List<GrammarExampleDto> examples;
  final String? mistakeWrong;
  final String? mistakeCorrect;
  final LocalizedMeaningsDto? relatedNote;
  final ContentProvenanceDto? provenance;
}

class GrammarLayerDto {
  const GrammarLayerDto({this.entries = const []});

  final List<GrammarEntryDto> entries;
}

class QuizEntryDto {
  const QuizEntryDto({
    required this.id,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanations,
    this.sourceNote,
    this.provenance,
  });

  final String id;

  /// [CreatorQuizCategory.storageKey].
  final String category;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final LocalizedMeaningsDto? explanations;
  final String? sourceNote;
  final ContentProvenanceDto? provenance;
}

class QuizLayerDto {
  const QuizLayerDto({this.entries = const []});

  final List<QuizEntryDto> entries;
}

/// Story-level audio. **Wire / remote** payloads should omit local-only fields
/// (see [StoryDraftMapper.fromDomainRemoteSafe]).
class StoryAudioDto {
  const StoryAudioDto({
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
  final String? localFileName;
  final String? localPath;
  final int? localSizeBytes;
  final String? localExtension;
  final String? displayName;
  final int? durationSeconds;
  final ContentProvenanceDto? provenance;
}

class AudioLayerDto {
  const AudioLayerDto({this.storyAudio});

  final StoryAudioDto? storyAudio;
}
