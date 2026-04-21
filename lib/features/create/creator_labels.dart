import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';

/// Centralized, user-facing label source of truth for creator drafts (V1).
abstract final class CreatorLabels {
  CreatorLabels._();

  /// Draft progress labels (editing state).
  static String progressLabelForLastActive(CreatorLastActiveModule m) {
    return switch (m) {
      CreatorLastActiveModule.storyBasics => 'Story basics in progress',
      CreatorLastActiveModule.storytelling => 'Storytelling in progress',
      CreatorLastActiveModule.semantics => 'Semantics in progress',
      CreatorLastActiveModule.grammar => 'Grammar in progress',
      CreatorLastActiveModule.quizzes => 'Quizzes in progress',
      CreatorLastActiveModule.listening => 'Listening in progress',
      // Review is still "editing state" but not part of the six core labels.
      CreatorLastActiveModule.review => 'Storytelling in progress',
    };
  }

  /// Readiness labels (publish readiness).
  ///
  /// V1 local creator flow keeps wording simple and avoids upload-state copy.
  static String readinessLabelForProcessingState(CreatorProcessingState s) {
    return switch (s) {
      CreatorProcessingState.localDraft => 'Draft only',
      CreatorProcessingState.localReadyReadOnly => 'Ready for Read-only',
      CreatorProcessingState.localReadyFullLearn => 'Ready for Full Learn',
      CreatorProcessingState.uploadQueued => 'Draft only',
      CreatorProcessingState.uploading => 'Draft only',
      CreatorProcessingState.uploaded => 'Draft only',
      CreatorProcessingState.uploadFailed => 'Draft only',
    };
  }
}

