import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/core/validation/text_normalization.dart' show charLength;
import 'package:nimon/features/create/creator_prompt_source_note.dart';
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

// -----------------------------------------------------------------------------
// HTML generator readiness context (source of truth for creator readiness)
// -----------------------------------------------------------------------------

class HtmlCreatorReadinessContext {
  const HtmlCreatorReadinessContext({
    required this.mode,
    required this.duration,
    required this.level,
    this.language = HtmlLearningLanguage.jp,
    this.preset = HtmlLimitPreset.defaultValue,
  });

  final HtmlPromptMode mode;
  final HtmlLearningLanguage language;
  final String duration; // '3-5 mins' | '5-7 mins' | '7-9 mins'
  final String level; // 'N5/A1' ... 'N1/C1'

  /// AI slider preset (V1: default only; manual ignores).
  final HtmlLimitPreset preset;
}

/// Canonical prompt-mode signal: [StoryBasics.promptSourceNote] (with import backfill).
String creatorDraftPromptSourceNote(CreatorStoryV1 draft) =>
    effectiveCreatorDraftPromptSourceNote(draft);

HtmlPromptMode resolveHtmlPromptModeForDraft(CreatorStoryV1 d) =>
    resolveHtmlPromptModeFromSourceNote(creatorDraftPromptSourceNote(d));

HtmlCreatorReadinessContext? resolveHtmlCreatorReadinessContext(
  CreatorStoryV1 draft,
) {
  final level = normalizeHtmlLevel(draft.level);
  final duration = normalizeHtmlDuration(draft.basics.targetDurationBandKey);
  if (level == null || duration == null) return null;
  return HtmlCreatorReadinessContext(
    mode: resolveHtmlPromptModeForDraft(draft),
    duration: duration,
    level: level,
  );
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

int _storyJapaneseCharCount(CreatorStoryV1 d) {
  var n = 0;
  for (final s in d.sentences) {
    final t = s.japaneseText.trim();
    if (t.isEmpty) continue;
    n += charLength(t.replaceAll(RegExp(r'\s'), ''));
  }
  return n;
}

({int vocabulary, int grammar, int sentence}) _quizDistributionCounts(
  CreatorStoryV1 d,
) {
  var v = 0;
  var g = 0;
  var s = 0;
  for (final q in d.quiz.entries) {
    if (!q.isValidV1) continue;
    switch (q.category) {
      case CreatorQuizCategory.vocabulary:
        v++;
      case CreatorQuizCategory.grammar:
        g++;
      case CreatorQuizCategory.sampleSentence:
        s++;
      case CreatorQuizCategory.kanji:
        // Counted in total quiz only (HTML distribution tables ignore kanji).
        break;
    }
  }
  return (vocabulary: v, grammar: g, sentence: s);
}

int? _exactSelected(HtmlSelectedCount c) => c is HtmlCountExact ? c.value : null;

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
  final m = computeStorySentencesStatus(draft);
  if (m.complete) return LearnModuleTaskStatus.completed;
  final current = _validSentencesCount(draft);
  if (current <= 0) return LearnModuleTaskStatus.notStarted;
  return LearnModuleTaskStatus.inProgress;
}

/// True when valid entry count meets the duration-band minimum for [id].
bool creatorLearnModuleMeetsCountMinimum(
  CreatorStoryV1 draft,
  LearnModuleId id, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final m = switch (id) {
    LearnModuleId.vocabularyKanji => computeVocabularyStatus(draft),
    LearnModuleId.grammar => computeGrammarStatus(draft),
    LearnModuleId.quiz => computeQuizStatus(draft),
    LearnModuleId.audio => computeListeningStatus(draft),
  };
  return m.complete;
}

LearnModuleTaskStatus learnModuleProgressTaskStatus(
  CreatorStoryV1 draft,
  LearnModuleId id, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final m = switch (id) {
    LearnModuleId.vocabularyKanji => computeVocabularyStatus(draft),
    LearnModuleId.grammar => computeGrammarStatus(draft),
    LearnModuleId.quiz => computeQuizStatus(draft),
    LearnModuleId.audio => computeListeningStatus(draft),
  };
  if (m.complete) return LearnModuleTaskStatus.completed;
  final current = switch (id) {
    LearnModuleId.vocabularyKanji => _validVocabCount(draft),
    LearnModuleId.grammar => _validGrammarCount(draft),
    LearnModuleId.quiz => _validQuizCount(draft),
    LearnModuleId.audio => _validAudioCount(draft),
  };
  if (current <= 0) return LearnModuleTaskStatus.notStarted;
  return LearnModuleTaskStatus.inProgress;
}

extension CreatorStoryV1LearnModuleThresholds on CreatorStoryV1 {
  /// HTML rules: module completion is computed from HTML generator limits.
  bool moduleMeetsHtmlCompletion(LearnModuleId id) =>
      creatorLearnModuleMeetsCountMinimum(this, id);

  bool get allLearnModulesDataComplete =>
      LearnModuleId.values.every(moduleMeetsHtmlCompletion);

  /// Full Learn publish (creator readiness): story core + every module satisfies HTML rules.
  ///
  /// NOTE: backend/client publish validation is unchanged in Phase 3.
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
  final ctx = resolveHtmlCreatorReadinessContext(draft);
  if (ctx == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Choose a target duration and level in Story basics',
    );
  }

  final lim = HtmlGeneratorLimits.sentenceLimit(
    mode: ctx.mode,
    language: ctx.language,
    duration: ctx.duration,
    level: ctx.level,
  );
  if (lim == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Story rules unavailable for this duration/level',
    );
  }

  final chars = _storyJapaneseCharCount(draft);
  final okCount = count >= lim.minSentences && count <= lim.maxSentences;
  final okChars = chars >= lim.minChars && chars <= lim.maxChars;
  final ok = okCount && okChars;

  final ratio = (count / lim.minSentences).clamp(0.0, 1.0).toDouble();
  final label =
      '$count/${lim.minSentences}–${lim.maxSentences} · $chars/${lim.minChars}–${lim.maxChars} chars';
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: label,
    unmetMessage: ok
        ? null
        : () {
            if (count < lim.minSentences) {
              return 'Need at least ${lim.minSentences} sentences';
            }
            if (count > lim.maxSentences) {
              return 'Too many sentences (max ${lim.maxSentences})';
            }
            if (chars < lim.minChars) {
              return 'Need at least ${lim.minChars} Japanese chars';
            }
            if (chars > lim.maxChars) {
              return 'Too many Japanese chars (max ${lim.maxChars})';
            }
            return 'Story sentences incomplete';
          }(),
  );
}

CreatorModuleCompletion computeVocabularyStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validVocabCount(draft);
  final ctx = resolveHtmlCreatorReadinessContext(draft);
  if (ctx == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Choose a target duration and level in Story basics',
    );
  }
  final lim = HtmlGeneratorLimits.vocabularyLimit(
    language: ctx.language,
    duration: ctx.duration,
    level: ctx.level,
  );
  if (lim == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Vocabulary rules unavailable for this duration/level',
    );
  }

  final requiredExact =
      _exactSelected(lim.selectedFor(HtmlPromptMode.ai, ctx.preset));
  final ok = ctx.mode == HtmlPromptMode.ai
      ? (requiredExact != null && count == requiredExact)
      : (count >= lim.manualMin && count <= lim.manualMax);

  final requiredLabel = ctx.mode == HtmlPromptMode.ai
      ? '${requiredExact ?? '—'}'
      : '${lim.manualMin}–${lim.manualMax}';

  final ratio = ctx.mode == HtmlPromptMode.ai
      ? ((requiredExact == null || requiredExact <= 0)
          ? 0.0
          : (count / requiredExact).clamp(0.0, 1.0).toDouble())
      : (count / lim.manualMin).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: '$count/$requiredLabel',
    unmetMessage: ok
        ? null
        : (ctx.mode == HtmlPromptMode.ai
            ? 'Need exactly $requiredLabel vocab items'
            : (count < lim.manualMin
                ? 'Need at least ${lim.manualMin} vocab items'
                : 'Too many vocab items (max ${lim.manualMax})')),
  );
}

CreatorModuleCompletion computeGrammarStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validGrammarCount(draft);
  final ctx = resolveHtmlCreatorReadinessContext(draft);
  if (ctx == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Choose a target duration and level in Story basics',
    );
  }
  final lim = HtmlGeneratorLimits.grammarLimit(
    language: ctx.language,
    duration: ctx.duration,
    level: ctx.level,
  );
  if (lim == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Grammar rules unavailable for this duration/level',
    );
  }

  final requiredExact =
      _exactSelected(lim.selectedFor(HtmlPromptMode.ai, ctx.preset));
  final ok = ctx.mode == HtmlPromptMode.ai
      ? (requiredExact != null && count == requiredExact)
      : (count >= lim.manualMin && count <= lim.manualMax);

  final requiredLabel = ctx.mode == HtmlPromptMode.ai
      ? '${requiredExact ?? '—'}'
      : '${lim.manualMin}–${lim.manualMax}';

  final ratio = ctx.mode == HtmlPromptMode.ai
      ? ((requiredExact == null || requiredExact <= 0)
          ? 0.0
          : (count / requiredExact).clamp(0.0, 1.0).toDouble())
      : (count / lim.manualMin).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: '$count/$requiredLabel',
    unmetMessage: ok
        ? null
        : (ctx.mode == HtmlPromptMode.ai
            ? 'Need exactly $requiredLabel grammar items'
            : (count < lim.manualMin
                ? 'Need at least ${lim.manualMin} grammar items'
                : 'Too many grammar items (max ${lim.manualMax})')),
  );
}

CreatorModuleCompletion computeQuizStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validQuizCount(draft);
  final ctx = resolveHtmlCreatorReadinessContext(draft);
  if (ctx == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Choose a target duration and level in Story basics',
    );
  }

  final dist = _quizDistributionCounts(draft);
  final totalLim = HtmlGeneratorLimits.quizLimit(
    duration: ctx.duration,
    level: ctx.level,
    quizCategory: 'Total Quiz',
  );
  final vLim = HtmlGeneratorLimits.quizLimit(
    duration: ctx.duration,
    level: ctx.level,
    quizCategory: 'Vocabulary Quiz',
  );
  final gLim = HtmlGeneratorLimits.quizLimit(
    duration: ctx.duration,
    level: ctx.level,
    quizCategory: 'Grammar Quiz',
  );
  final sLim = HtmlGeneratorLimits.quizLimit(
    duration: ctx.duration,
    level: ctx.level,
    quizCategory: 'Sentence Quiz',
  );

  if (totalLim == null || vLim == null || gLim == null || sLim == null) {
    return CreatorModuleCompletion(
      state: CreatorCompletionState.open,
      complete: false,
      ratio: 0.0,
      countLabel: '$count/—',
      unmetMessage: 'Quiz rules unavailable for this duration/level',
    );
  }

  final selected = ctx.mode == HtmlPromptMode.ai
      ? HtmlGeneratorLimits.selectedFullLearnLimits(
          mode: HtmlPromptMode.ai,
          language: ctx.language,
          duration: ctx.duration,
          level: ctx.level,
          preset: ctx.preset,
        )
      : null;

  final ok = ctx.mode == HtmlPromptMode.ai
      ? (selected != null &&
          count == selected.totalQuizCount &&
          dist.vocabulary == selected.vocabularyQuizCount &&
          dist.grammar == selected.grammarQuizCount &&
          dist.sentence == selected.sentenceQuizCount)
      : (count >= totalLim.manualMin &&
          count <= totalLim.manualMax &&
          dist.vocabulary >= vLim.manualMin &&
          dist.vocabulary <= vLim.manualMax &&
          dist.grammar >= gLim.manualMin &&
          dist.grammar <= gLim.manualMax &&
          dist.sentence >= sLim.manualMin &&
          dist.sentence <= sLim.manualMax);

  final label = ctx.mode == HtmlPromptMode.ai && selected != null
      ? '$count/${selected.totalQuizCount} · '
          'v${dist.vocabulary}/${selected.vocabularyQuizCount} '
          'g${dist.grammar}/${selected.grammarQuizCount} '
          's${dist.sentence}/${selected.sentenceQuizCount}'
      : '$count/${totalLim.manualMin}–${totalLim.manualMax} · '
          'v${dist.vocabulary}/${vLim.manualMin}–${vLim.manualMax} '
          'g${dist.grammar}/${gLim.manualMin}–${gLim.manualMax} '
          's${dist.sentence}/${sLim.manualMin}–${sLim.manualMax}';

  final ratio = ctx.mode == HtmlPromptMode.ai
      ? ((selected == null || selected.totalQuizCount <= 0)
          ? 0.0
          : (count / selected.totalQuizCount).clamp(0.0, 1.0).toDouble())
      : (count / totalLim.manualMin).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: label,
    unmetMessage: ok
        ? null
        : (ctx.mode == HtmlPromptMode.ai && selected != null
            ? (count != selected.totalQuizCount
                ? 'Need exactly ${selected.totalQuizCount} quizzes total'
                : 'Need quiz distribution: '
                    'vocabulary ${selected.vocabularyQuizCount}, '
                    'grammar ${selected.grammarQuizCount}, '
                    'sentence ${selected.sentenceQuizCount}')
            : () {
                if (count < totalLim.manualMin) {
                  return 'Need at least ${totalLim.manualMin} quizzes total';
                }
                if (count > totalLim.manualMax) {
                  return 'Too many quizzes (max ${totalLim.manualMax})';
                }
                return 'Need quiz distribution: '
                    'vocabulary ${vLim.manualMin}–${vLim.manualMax}, '
                    'grammar ${gLim.manualMin}–${gLim.manualMax}, '
                    'sentence ${sLim.manualMin}–${sLim.manualMax}';
              }()),
  );
}

CreatorModuleCompletion computeListeningStatus(
  CreatorStoryV1 draft, {
  CreatorV1DurationThresholds? thresholds,
}) {
  final count = _validAudioCount(draft);
  final ok = count >= 1;
  final ratio = (count / 1).clamp(0.0, 1.0).toDouble();
  return CreatorModuleCompletion(
    state: ok ? CreatorCompletionState.complete : CreatorCompletionState.open,
    complete: ok,
    ratio: ratio,
    countLabel: '$count/1',
    unmetMessage: ok ? null : 'Need audio for Full Learn',
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

  final basics = withCurrent(
    computeStoryBasicsStatus(draft, thresholds: thresholds),
    CreatorStepId.basics,
  );
  final sentences = withCurrent(
    computeStorySentencesStatus(draft, thresholds: thresholds),
    CreatorStepId.sentences,
  );
  final vocab = withCurrent(
    computeVocabularyStatus(draft, thresholds: thresholds),
    CreatorStepId.vocabulary,
  );
  final grammar = withCurrent(
    computeGrammarStatus(draft, thresholds: thresholds),
    CreatorStepId.grammar,
  );
  final quiz = withCurrent(
    computeQuizStatus(draft, thresholds: thresholds),
    CreatorStepId.quiz,
  );
  final listening = withCurrent(
    computeListeningStatus(draft, thresholds: thresholds),
    CreatorStepId.listening,
  );

  if (kDebugMode) {
    final ctx = resolveHtmlCreatorReadinessContext(draft);
    debugPrint(
      '[creator_html_rules] ctx=${ctx == null ? 'missing' : '${ctx.duration} ${ctx.level} ${ctx.mode.name}'}',
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
    if (story.moduleMeetsHtmlCompletion(id)) {
      m[id] = LearnModuleTaskStatus.completed;
    }
  }
  return story.copyWith(moduleWorkflowStatuses: m);
}
