import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// User-facing copy for Profile > Processing cards (V1 publish targets).
abstract final class CreatorProcessingCopy {
  CreatorProcessingCopy._();

  /// Primary status chip — one explicit state only.
  static String primaryStatus(StoryPublishState p) => switch (p) {
        StoryPublishState.draft => 'Draft',
        StoryPublishState.readingOnlyPublished => 'Read Only published',
        StoryPublishState.fullLearnPublished => 'Full Learn published',
      };

  /// Secondary line under the title (not the technical readiness enum).
  static String secondaryLine(CreatorStoryV1 draft) {
    switch (draft.publishState) {
      case StoryPublishState.draft:
        return 'Continue editing';
      case StoryPublishState.readingOnlyPublished:
        return computeFullLearnReady(draft).ready
            ? 'Ready to publish Full Learn'
            : 'Learn upgrade available';
      case StoryPublishState.fullLearnPublished:
        return 'All modules complete';
    }
  }

  /// Primary row action — matches the next real task.
  static String primaryButton(StoryPublishState p) => switch (p) {
        StoryPublishState.draft => 'Continue',
        StoryPublishState.readingOnlyPublished => 'Continue Learn',
        StoryPublishState.fullLearnPublished => 'Edit',
      };
}
