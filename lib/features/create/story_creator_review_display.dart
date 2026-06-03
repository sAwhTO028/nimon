import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Publish intent for Read Only vs Full Learn (confirmed on publish).
enum StoryReviewPublishMode {
  readingOnly,
  fullLearn,
}

/// Readiness snapshot for creator publish — rules live in [computeReadOnlyReady] / [computeFullLearnReady].
class StoryReviewDisplayModel {
  const StoryReviewDisplayModel({
    required this.isStoryCoreReady,
    required this.isReadingOnlyReady,
    required this.isFullLearnReady,
    required this.completedLearnModuleCount,
    required this.totalLearnModuleCount,
    required this.readOnly,
    required this.fullLearn,
  });

  final bool isStoryCoreReady;
  final bool isReadingOnlyReady;
  final bool isFullLearnReady;
  final int completedLearnModuleCount;
  final int totalLearnModuleCount;
  final CreatorReadinessResult readOnly;
  final CreatorReadinessResult fullLearn;
}

const int kStoryReviewLearnModuleTotal = 4;

/// Builds the publish readiness snapshot from the current draft using [computeReadOnlyReady] / [computeFullLearnReady]
/// and module completion flags — no duplicate business rules.
StoryReviewDisplayModel buildStoryReviewDisplayModel(CreatorStoryV1 draft) {
  final readOnly = computeReadOnlyReady(draft);
  final fullLearn = computeFullLearnReady(draft);
  var n = 0;
  if (computeVocabularyStatus(draft).complete) n++;
  if (computeGrammarStatus(draft).complete) n++;
  if (computeQuizStatus(draft).complete) n++;
  if (computeListeningStatus(draft).complete) n++;

  return StoryReviewDisplayModel(
    isStoryCoreReady: readOnly.ready,
    isReadingOnlyReady: readOnly.ready,
    isFullLearnReady: fullLearn.ready,
    completedLearnModuleCount: n,
    totalLearnModuleCount: kStoryReviewLearnModuleTotal,
    readOnly: readOnly,
    fullLearn: fullLearn,
  );
}

/// Whether the given mode can be activated given current readiness.
bool isStoryReviewModeAllowed(
  StoryReviewPublishMode mode,
  StoryReviewDisplayModel model,
) {
  return switch (mode) {
    StoryReviewPublishMode.readingOnly => model.isReadingOnlyReady,
    StoryReviewPublishMode.fullLearn => model.isFullLearnReady,
  };
}

/// Default segmented selection: persisted choice when still valid, else publish state hint, else rules.
StoryReviewPublishMode resolveDefaultStoryReviewMode({
  required StoryReviewDisplayModel model,
  required StoryPublishState draftPublishState,
  StoryReviewPublishMode? lastExplicitChoice,
}) {
  bool allowed(StoryReviewPublishMode m) => isStoryReviewModeAllowed(m, model);

  if (lastExplicitChoice != null && allowed(lastExplicitChoice)) {
    return lastExplicitChoice;
  }

  final fromPublish = switch (draftPublishState) {
    StoryPublishState.draft => null,
    StoryPublishState.readingOnlyPublished =>
      StoryReviewPublishMode.readingOnly,
    StoryPublishState.fullLearnPublished => StoryReviewPublishMode.fullLearn,
  };
  if (fromPublish != null && allowed(fromPublish)) {
    return fromPublish;
  }

  if (model.isFullLearnReady) {
    return StoryReviewPublishMode.readingOnly;
  }
  if (model.isReadingOnlyReady) {
    return StoryReviewPublishMode.readingOnly;
  }
  return StoryReviewPublishMode.readingOnly;
}

/// Unmet lines for the **selected** publish type only.
List<String> storyReviewUnmetForMode(
  StoryReviewPublishMode mode,
  StoryReviewDisplayModel model,
) {
  final raw = switch (mode) {
    StoryReviewPublishMode.readingOnly => model.readOnly.unmetMessages,
    StoryReviewPublishMode.fullLearn => model.fullLearn.unmetMessages,
  };
  return _dedupeHumanized(
    raw.map(_humanizeReviewUnmet).where((s) => s.trim().isNotEmpty),
  );
}

List<String> _dedupeHumanized(Iterable<String> items) {
  final out = <String>[];
  final seen = <String>{};
  for (final s in items) {
    final t = s.trim();
    if (t.isEmpty || seen.contains(t)) continue;
    seen.add(t);
    out.add(t);
  }
  return out;
}

/// Maps internal completion strings to concise, user-facing copy.
String _humanizeReviewUnmet(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  final lower = t.toLowerCase();

  if (lower.contains('vocabulary')) {
    return 'Complete Vocabulary / Kanji';
  }
  if (lower.contains('grammar')) {
    return 'Complete Grammar';
  }
  if (lower.contains('quiz')) {
    return 'Complete Quiz';
  }
  if (lower.contains('audio') ||
      lower.contains('listening') ||
      lower.contains('attach')) {
    return 'Attach 1 audio file';
  }
  if (lower.contains('story basics') ||
      (lower.contains('duration') && lower.contains('choose'))) {
    return 'Complete story basics';
  }
  if (lower.contains('title') ||
      lower.contains('description') ||
      lower.contains('category') ||
      lower.contains('level')) {
    return 'Complete story basics';
  }
  if (lower.contains('sentence')) {
    if (lower.startsWith('add ')) return t;
    return 'Add enough story sentences';
  }
  return t;
}
