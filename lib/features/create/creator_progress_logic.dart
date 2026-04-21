import 'package:nimon/features/create/story_creator_models.dart';

/// V1 creator checklist: derives [LearnModuleTaskStatus] for Story Core and Learn rows
/// from [CreatorStoryV1] fields. Rules live in [learnModuleTaskStatusFromCountThreshold]
/// and related helpers in [creator_completion_rules.dart].
extension CreatorStoryV1Progress on CreatorStoryV1 {
  /// Story basics: five required fields (aligned with [computeStoryBasicsStatus]).
  LearnModuleTaskStatus get basicsProgressStatus =>
      learnModuleTaskStatusFromStoryBasics(this);

  /// Story sentences: valid sentence count vs duration-band minimum.
  LearnModuleTaskStatus get sentencesProgressStatus =>
      learnModuleTaskStatusFromStorySentences(this);

  /// Learn module row: count vs threshold (aligned with [computeVocabularyStatus] / …).
  LearnModuleTaskStatus learnModuleProgressStatus(LearnModuleId id) =>
      learnModuleProgressTaskStatus(this, id);

  String? basicsProgressHint() {
    if (computeStoryBasicsStatus(this).complete) return null;
    if (basicsProgressStatus == LearnModuleTaskStatus.notStarted) {
      return 'Open Story basics to add title, category, level, and description.';
    }
    return 'All of title, category, level, and description are required.';
  }

  String? sentencesProgressHint() {
    final t = resolveV1ThresholdsForDraft(this);
    final m = computeStorySentencesStatus(this, thresholds: t);
    if (m.complete) return null;
    return m.unmetMessage;
  }

  String? learnModuleProgressHint(LearnModuleId id) {
    final t = resolveV1ThresholdsForDraft(this);
    final m = switch (id) {
      LearnModuleId.vocabularyKanji =>
        computeVocabularyStatus(this, thresholds: t),
      LearnModuleId.grammar => computeGrammarStatus(this, thresholds: t),
      LearnModuleId.quiz => computeQuizStatus(this, thresholds: t),
      LearnModuleId.audio => computeListeningStatus(this, thresholds: t),
    };
    if (m.complete) return null;
    return m.unmetMessage;
  }

  String learnModuleProgressLabel(LearnModuleId id) =>
      learnModuleTaskStatusLabel(learnModuleProgressStatus(id));
}

String learnModuleTaskStatusLabel(LearnModuleTaskStatus s) => switch (s) {
      LearnModuleTaskStatus.notStarted => 'Not started',
      LearnModuleTaskStatus.inProgress => 'In progress',
      LearnModuleTaskStatus.completed => 'Complete',
    };
