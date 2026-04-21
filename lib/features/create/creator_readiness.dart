import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:nimon/features/create/creator_labels.dart';
import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Local-only processing states for creator drafts (V1).
enum CreatorProcessingState {
  localDraft,
  localReadyReadOnly,
  localReadyFullLearn,
  uploadQueued,
  uploading,
  uploaded,
  uploadFailed,
}

extension CreatorProcessingStateLabel on CreatorProcessingState {
  String get displayLabel => switch (this) {
        _ => CreatorLabels.readinessLabelForProcessingState(this),
      };
}

class CreatorReadinessResult {
  const CreatorReadinessResult({
    required this.ready,
    required this.unmetMessages,
  });

  final bool ready;
  final List<String> unmetMessages;
}

CreatorReadinessResult computeReadOnlyReady(
  CreatorStoryV1 draft,
) {
  final t = resolveV1ThresholdsForDraft(draft);
  final basics = computeStoryBasicsStatus(draft, thresholds: t);
  final sentences = computeStorySentencesStatus(draft, thresholds: t);

  final unmet = <String>[
    if (!basics.complete) 'Complete Story basics',
    if (!sentences.complete)
      (sentences.unmetMessage ?? 'Story sentences incomplete'),
  ];
  final ready = unmet.isEmpty;
  if (kDebugMode) {
    debugPrint(
      '[creator_thresholds] duration=${t == null ? 'missing' : t.band.storageKey}',
    );
    debugPrint(
      '[creator_thresholds] story=${sentences.countLabel}',
    );
    debugPrint('[creator_readiness] readOnlyReady=$ready');
    if (!ready) debugPrint('[creator_readiness] unmet=${unmet.join(' | ')}');
  }
  return CreatorReadinessResult(ready: ready, unmetMessages: unmet);
}

CreatorReadinessResult computeFullLearnReady(
  CreatorStoryV1 draft,
) {
  final t = resolveV1ThresholdsForDraft(draft);
  final basics = computeStoryBasicsStatus(draft, thresholds: t);
  final sentences = computeStorySentencesStatus(draft, thresholds: t);
  final vocab = computeVocabularyStatus(draft, thresholds: t);
  final grammar = computeGrammarStatus(draft, thresholds: t);
  final quiz = computeQuizStatus(draft, thresholds: t);
  final listening = computeListeningStatus(draft, thresholds: t);

  final unmet = <String>[
    if (!basics.complete) 'Complete Story basics',
    if (!sentences.complete)
      (sentences.unmetMessage ?? 'Story sentences incomplete'),
    if (basics.complete && sentences.complete && !vocab.complete)
      (vocab.unmetMessage ?? 'Vocabulary incomplete'),
    if (basics.complete && sentences.complete && !grammar.complete)
      (grammar.unmetMessage ?? 'Grammar incomplete'),
    if (basics.complete && sentences.complete && !quiz.complete)
      (quiz.unmetMessage ?? 'Quiz incomplete'),
    if (basics.complete && sentences.complete && !listening.complete)
      (listening.unmetMessage ?? 'Listening incomplete'),
  ];

  final ready = unmet.isEmpty;
  if (kDebugMode) {
    debugPrint(
      '[creator_thresholds] duration=${t == null ? 'missing' : t.band.storageKey}',
    );
    debugPrint('[creator_thresholds] story=${sentences.countLabel}');
    debugPrint('[creator_thresholds] vocab=${vocab.countLabel}');
    debugPrint('[creator_thresholds] grammar=${grammar.countLabel}');
    debugPrint('[creator_thresholds] quiz=${quiz.countLabel}');
    debugPrint('[creator_thresholds] listening=${listening.countLabel}');
    debugPrint('[creator_readiness] fullLearnReady=$ready');
    if (!ready) debugPrint('[creator_readiness] unmet=${unmet.join(' | ')}');
  }
  return CreatorReadinessResult(ready: ready, unmetMessages: unmet);
}

CreatorProcessingState computeProcessingState(
  CreatorStoryV1 draft,
) {
  final ro = computeReadOnlyReady(draft);
  final fl = computeFullLearnReady(draft);
  final state = fl.ready
      ? CreatorProcessingState.localReadyFullLearn
      : ro.ready
          ? CreatorProcessingState.localReadyReadOnly
          : CreatorProcessingState.localDraft;
  if (kDebugMode) {
    debugPrint('[creator_processing] state=${state.displayLabel}');
  }
  return state;
}

