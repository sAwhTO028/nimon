import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:nimon/features/create/creator_step_id.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// System-driven completion rules for the creator workflow (V1).
///
/// - Centralizes thresholds (easy to adjust later)
/// - Computes Open / Current / Complete from *real draft data*
/// - Provides unmet requirement helper text + counts for UI
///
/// IMPORTANT: do not persist manual completion flags; they drift from content.

enum CreatorCompletionState { open, current, complete }

/// Story duration bands used for V1 completion/readiness thresholds.
enum CreatorDurationBand {
  mins3to5,
  mins5to7,
  mins7to9,
}

extension CreatorDurationBandLabels on CreatorDurationBand {
  String get storageKey => switch (this) {
        CreatorDurationBand.mins3to5 => '3_5',
        CreatorDurationBand.mins5to7 => '5_7',
        CreatorDurationBand.mins7to9 => '7_9',
      };

  String get displayLabel => switch (this) {
        CreatorDurationBand.mins3to5 => '3–5 mins',
        CreatorDurationBand.mins5to7 => '5–7 mins',
        CreatorDurationBand.mins7to9 => '7–9 mins',
      };
}

/// Centralized V1 minimum thresholds resolved by duration band.
class CreatorV1DurationThresholds {
  const CreatorV1DurationThresholds({
    required this.band,
    required this.minStorySentences,
    required this.minVocabularyEntries,
    required this.minGrammarEntries,
    required this.minQuizEntries,
    this.minListeningAudioItems = 1,
  });

  final CreatorDurationBand band;
  final int minStorySentences;
  final int minVocabularyEntries;
  final int minGrammarEntries;
  final int minQuizEntries;
  final int minListeningAudioItems;

  static const byBand = <CreatorDurationBand, CreatorV1DurationThresholds>{
    // Duration band: 3–5 minutes
    CreatorDurationBand.mins3to5: CreatorV1DurationThresholds(
      band: CreatorDurationBand.mins3to5,
      minStorySentences: 8,
      minVocabularyEntries: 6,
      minGrammarEntries: 3,
      minQuizEntries: 4,
      minListeningAudioItems: 1,
    ),
    // Duration band: 5–7 minutes
    CreatorDurationBand.mins5to7: CreatorV1DurationThresholds(
      band: CreatorDurationBand.mins5to7,
      minStorySentences: 14,
      minVocabularyEntries: 9,
      minGrammarEntries: 4,
      minQuizEntries: 6,
      minListeningAudioItems: 1,
    ),
    // Duration band: 7–9 minutes
    CreatorDurationBand.mins7to9: CreatorV1DurationThresholds(
      band: CreatorDurationBand.mins7to9,
      minStorySentences: 20,
      minVocabularyEntries: 12,
      minGrammarEntries: 6,
      minQuizEntries: 8,
      minListeningAudioItems: 1,
    ),
  };
}

class CreatorModuleCompletion {
  const CreatorModuleCompletion({
    required this.state,
    required this.complete,
    required this.ratio,
    required this.countLabel,
    required this.unmetMessage,
  });

  final CreatorCompletionState state;
  final bool complete;
  final double ratio;
  final String countLabel;
  final String? unmetMessage;

  CreatorModuleCompletion withState(CreatorCompletionState s) {
    return CreatorModuleCompletion(
      state: s,
      complete: complete,
      ratio: ratio,
      countLabel: countLabel,
      unmetMessage: unmetMessage,
    );
  }
}

class CreatorProgressSnapshot {
  const CreatorProgressSnapshot({
    required this.basics,
    required this.sentences,
    required this.vocabulary,
    required this.grammar,
    required this.quiz,
    required this.listening,
  });

  final CreatorModuleCompletion basics;
  final CreatorModuleCompletion sentences;
  final CreatorModuleCompletion vocabulary;
  final CreatorModuleCompletion grammar;
  final CreatorModuleCompletion quiz;
  final CreatorModuleCompletion listening;
}

int _validSentencesCount(CreatorStoryV1 d) =>
    d.sentences.where((s) => s.isValidV1).length;

int _validVocabCount(CreatorStoryV1 d) =>
    d.vocabularyKanji.entries.where((e) => e.isValidV1).length;

int _validGrammarCount(CreatorStoryV1 d) =>
    d.grammar.entries.where((e) => e.isValidV1).length;

int _validQuizCount(CreatorStoryV1 d) =>
    d.quiz.entries.where((e) => e.isValidV1).length;

int _validAudioCount(CreatorStoryV1 d) =>
    (d.audio.storyAudio?.isValidV1 == true) ? 1 : 0;

// -----------------------------------------------------------------------------
// Count-based task status (drawer chips + publish alignment)
// -----------------------------------------------------------------------------

/// V1 rule for any module measured as **current count vs required minimum**:
///
/// - [current] == 0 → [LearnModuleTaskStatus.notStarted]
/// - 0 < [current] < [requiredCount] → [LearnModuleTaskStatus.inProgress]
/// - [current] >= [requiredCount] → [LearnModuleTaskStatus.completed]
///
/// When [requiredCount] is null (e.g. duration band not chosen), completion is
/// unreachable: 0 → not started; above 0 → in progress.
LearnModuleTaskStatus learnModuleTaskStatusFromCountThreshold({
  required int current,
  required int? requiredCount,
}) {
  if (requiredCount == null || requiredCount <= 0) {
    if (current <= 0) return LearnModuleTaskStatus.notStarted;
    return LearnModuleTaskStatus.inProgress;
  }
  if (current <= 0) return LearnModuleTaskStatus.notStarted;
  if (current < requiredCount) return LearnModuleTaskStatus.inProgress;
  return LearnModuleTaskStatus.completed;
}

/// Story basics: five required fields (title, description, level, category, duration band).
LearnModuleTaskStatus learnModuleTaskStatusFromStoryBasics(
    CreatorStoryV1 draft) {
  final resolved = resolveV1ThresholdsForDraft(draft);
  final hasDuration = resolved != null;
  final hasTitle = draft.title.trim().isNotEmpty;
  final hasDesc = draft.description.trim().isNotEmpty;
  final hasLevel = draft.level.trim().isNotEmpty;
  final hasCategory = draft.category.trim().isNotEmpty;
  final metCount = [hasTitle, hasDesc, hasLevel, hasCategory, hasDuration]
      .where((x) => x)
      .length;
  return learnModuleTaskStatusFromCountThreshold(
    current: metCount,
    requiredCount: 5,
  );
}

LearnModuleTaskStatus learnModuleTaskStatusFromStorySentences(
    CreatorStoryV1 draft) {
  final count = _validSentencesCount(draft);
  final resolved = resolveV1ThresholdsForDraft(draft);
  final min = resolved?.minStorySentences;
  return learnModuleTaskStatusFromCountThreshold(
    current: count,
    requiredCount: min,
  );
}

/// True when valid entry count meets the duration-band minimum for [id].
bool creatorLearnModuleMeetsCountMinimum(
  CreatorStoryV1 draft,
  LearnModuleId id, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final t = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = switch (id) {
    LearnModuleId.vocabularyKanji => t?.minVocabularyEntries,
    LearnModuleId.grammar => t?.minGrammarEntries,
    LearnModuleId.quiz => t?.minQuizEntries,
    LearnModuleId.audio => t?.minListeningAudioItems,
  };
  final current = switch (id) {
    LearnModuleId.vocabularyKanji => _validVocabCount(draft),
    LearnModuleId.grammar => _validGrammarCount(draft),
    LearnModuleId.quiz => _validQuizCount(draft),
    LearnModuleId.audio => _validAudioCount(draft),
  };
  return min != null && min > 0 && current >= min;
}

LearnModuleTaskStatus learnModuleProgressTaskStatus(
  CreatorStoryV1 draft,
  LearnModuleId id, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final t = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = switch (id) {
    LearnModuleId.vocabularyKanji => t?.minVocabularyEntries,
    LearnModuleId.grammar => t?.minGrammarEntries,
    LearnModuleId.quiz => t?.minQuizEntries,
    LearnModuleId.audio => t?.minListeningAudioItems,
  };
  final current = switch (id) {
    LearnModuleId.vocabularyKanji => _validVocabCount(draft),
    LearnModuleId.grammar => _validGrammarCount(draft),
    LearnModuleId.quiz => _validQuizCount(draft),
    LearnModuleId.audio => _validAudioCount(draft),
  };
  return learnModuleTaskStatusFromCountThreshold(
    current: current,
    requiredCount: min,
  );
}

extension CreatorStoryV1LearnModuleThresholds on CreatorStoryV1 {
  /// V1: meets duration-band minimum valid-entry counts (aligned with [computeVocabularyStatus] / …).
  bool moduleMeetsV1Completion(LearnModuleId id) =>
      creatorLearnModuleMeetsCountMinimum(this, id);

  bool get allLearnModulesDataComplete =>
      LearnModuleId.values.every(moduleMeetsV1Completion);

  /// Full Learn publish: core + every module satisfies its V1 data bar.
  bool get canPublishFullLearn =>
      isStoryCoreReadyForReading && allLearnModulesDataComplete;
}

CreatorDurationBand? _durationBandFromDraftV1(CreatorStoryV1 d) {
  // V1 source of truth:
  // - Prefer explicit `StoryBasics.targetDurationBandKey` when present.
  // - Back-compat fallback: parse legacy text inside `promptSourceNote`
  //   (e.g. "Target duration: 5–7 mins").
  // - If missing/invalid, fail safely (treat readiness as incomplete).
  final key = (d.basics.targetDurationBandKey ?? '').trim();
  if (key.isNotEmpty) {
    return switch (key) {
      '3_5' => CreatorDurationBand.mins3to5,
      '5_7' => CreatorDurationBand.mins5to7,
      '7_9' => CreatorDurationBand.mins7to9,
      _ => null,
    };
  }
  final raw = d.promptSourceNote.trim();
  if (raw.isEmpty) return null;
  // Normalize hyphen variants: '-', '–', '—'
  final s = raw
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('to', '-')
      .toLowerCase();
  if (s.contains('3-5')) return CreatorDurationBand.mins3to5;
  if (s.contains('5-7')) return CreatorDurationBand.mins5to7;
  if (s.contains('7-9')) return CreatorDurationBand.mins7to9;

  // Fallback: detect both endpoints (e.g. "3 - 5 mins")
  if (s.contains('3') && s.contains('5') && s.contains('min')) {
    return CreatorDurationBand.mins3to5;
  }
  if (s.contains('5') && s.contains('7') && s.contains('min')) {
    return CreatorDurationBand.mins5to7;
  }
  if (s.contains('7') && s.contains('9') && s.contains('min')) {
    return CreatorDurationBand.mins7to9;
  }
  return null;
}

CreatorV1DurationThresholds? resolveV1ThresholdsForDraft(CreatorStoryV1 draft) {
  final band = _durationBandFromDraftV1(draft);
  if (band == null) return null;
  return CreatorV1DurationThresholds.byBand[band];
}

CreatorModuleCompletion computeStoryBasicsStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final hasTitle = draft.title.trim().isNotEmpty;
  final hasDesc = draft.description.trim().isNotEmpty;
  final hasLevel = draft.level.trim().isNotEmpty;
  final hasCategory = draft.category.trim().isNotEmpty;
  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final hasDuration = resolved != null;

  final ok = hasTitle && hasDesc && hasLevel && hasCategory && hasDuration;

  final unmet = ok
      ? null
      : () {
          final missing = <String>[
            if (!hasTitle) 'title',
            if (!hasDesc) 'description',
            if (!hasLevel) 'level',
            if (!hasCategory) 'category',
            if (!hasDuration) 'duration',
          ];
          return 'Add ${missing.join(', ')}';
        }();

  final metCount = [hasTitle, hasDesc, hasLevel, hasCategory, hasDuration]
      .where((x) => x)
      .length;
  final ratio = metCount / 5.0;
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio.clamp(0, 1),
    countLabel: 'Required: $metCount/5',
    unmetMessage: unmet,
  );
}

CreatorModuleCompletion computeStorySentencesStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validSentencesCount(draft);
  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = resolved?.minStorySentences;
  final ok = min != null && count >= min;
  final ratio = (min == null || min <= 0)
      ? 0.0
      : (count / min).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: min == null ? '$count/—' : '$count/$min',
    unmetMessage: ok
        ? null
        : (min == null
            ? 'Choose a target duration in Story basics'
            : 'Add at least $min story sentences'),
  );
}

CreatorModuleCompletion computeVocabularyStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validVocabCount(draft);
  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = resolved?.minVocabularyEntries;
  final ok = min != null && count >= min;
  final ratio = (min == null || min <= 0)
      ? 0.0
      : (count / min).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: min == null ? '$count/—' : '$count/$min',
    unmetMessage: ok
        ? null
        : (min == null
            ? 'Choose a target duration in Story basics'
            : 'Add at least $min vocabulary items'),
  );
}

CreatorModuleCompletion computeGrammarStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validGrammarCount(draft);
  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = resolved?.minGrammarEntries;
  final ok = min != null && count >= min;
  final ratio = (min == null || min <= 0)
      ? 0.0
      : (count / min).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: min == null ? '$count/—' : '$count/$min',
    unmetMessage: ok
        ? null
        : (min == null
            ? 'Choose a target duration in Story basics'
            : 'Add at least $min grammar items'),
  );
}

CreatorModuleCompletion computeQuizStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validQuizCount(draft);
  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = resolved?.minQuizEntries;
  final ok = min != null && count >= min;
  final ratio = (min == null || min <= 0)
      ? 0.0
      : (count / min).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: min == null ? '$count/—' : '$count/$min',
    unmetMessage: ok
        ? null
        : (min == null
            ? 'Choose a target duration in Story basics'
            : 'Add at least $min quizzes'),
  );
}

CreatorModuleCompletion computeListeningStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validAudioCount(draft);
  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);
  final min = resolved?.minListeningAudioItems;
  final ok = min != null && count >= min;
  final ratio = (min == null || min <= 0)
      ? 0.0
      : (count / min).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: min == null ? '$count/—' : '$count/$min',
    unmetMessage: ok
        ? null
        : (min == null
            ? 'Choose a target duration in Story basics'
            : 'Attach 1 audio file'),
  );
}

CreatorProgressSnapshot computeCreatorProgressSnapshot(
  CreatorStoryV1 draft, {
  required CreatorStepId? activeStep,
  CreatorV1DurationThresholds? thresholds,
}) {
  CreatorModuleCompletion withCurrent(
    CreatorModuleCompletion base,
    CreatorStepId step,
  ) {
    if (activeStep == step)
      return base.withState(CreatorCompletionState.current);
    return base;
  }

  final resolved = thresholds ?? resolveV1ThresholdsForDraft(draft);

  final basics = withCurrent(
    computeStoryBasicsStatus(draft, thresholds: resolved),
    CreatorStepId.basics,
  );
  final sentences = withCurrent(
    computeStorySentencesStatus(draft, thresholds: resolved),
    CreatorStepId.sentences,
  );
  final vocab = withCurrent(
    computeVocabularyStatus(draft, thresholds: resolved),
    CreatorStepId.vocabulary,
  );
  final grammar = withCurrent(
    computeGrammarStatus(draft, thresholds: resolved),
    CreatorStepId.grammar,
  );
  final quiz = withCurrent(
    computeQuizStatus(draft, thresholds: resolved),
    CreatorStepId.quiz,
  );
  final listening = withCurrent(
    computeListeningStatus(draft, thresholds: resolved),
    CreatorStepId.listening,
  );

  if (kDebugMode) {
    final band = resolved?.band;
    debugPrint(
      '[creator_thresholds] duration=${band == null ? 'missing' : band.storageKey}',
    );
    debugPrint('[creator_status] activeModule=$activeStep');
    debugPrint('[creator_status] basics=${basics.state} ${basics.countLabel}');
    debugPrint(
        '[creator_status] sentences=${sentences.state} ${sentences.countLabel}');
    debugPrint(
        '[creator_status] vocabulary=${vocab.state} ${vocab.countLabel}');
    debugPrint(
        '[creator_status] grammar=${grammar.state} ${grammar.countLabel}');
    debugPrint('[creator_status] quiz=${quiz.state} ${quiz.countLabel}');
    debugPrint(
        '[creator_status] listening=${listening.state} ${listening.countLabel}');
    debugPrint('[creator_status] snapshot_ready');
  }

  return CreatorProgressSnapshot(
    basics: basics,
    sentences: sentences,
    vocabulary: vocab,
    grammar: grammar,
    quiz: quiz,
    listening: listening,
  );
}

/// When module data crosses V1 threshold, promote workflow status to completed.
CreatorStoryV1 syncModuleWorkflowWithContent(CreatorStoryV1 story) {
  final m = Map<LearnModuleId, LearnModuleTaskStatus>.from(
    story.moduleWorkflowStatuses,
  );
  for (final id in LearnModuleId.values) {
    if (story.moduleMeetsV1Completion(id)) {
      m[id] = LearnModuleTaskStatus.completed;
    }
  }
  return story.copyWith(moduleWorkflowStatuses: m);
}
