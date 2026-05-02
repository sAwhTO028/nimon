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

  /// Profile Workspace list rows backed by [DraftListSummaryDto] only (no full draft parse).
  ///
  /// Differs from [secondaryLine] by omitting [computeFullLearnReady] — RO rows always show the
  /// generic learn-upgrade hint until the editor loads full state.
  static String secondaryLineSummaryOnly(StoryPublishState publishState) {
    switch (publishState) {
      case StoryPublishState.draft:
        return 'Continue editing';
      case StoryPublishState.readingOnlyPublished:
        return 'Learn upgrade available';
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

  /// List-row duration chip from API `targetDurationBandKey` (`3_5`, `5_7`, `7_9`).
  static String draftSummaryDurationChip(String? targetDurationBandKey) {
    final k = targetDurationBandKey?.trim() ?? '';
    if (k.isEmpty) return '—';
    for (final b in CreatorDurationBand.values) {
      if (b.storageKey == k) return b.displayLabel;
    }
    return '—';
  }

  /// Short label for [DraftListSummaryDto.lastEditingStep] (module id from backend).
  static String draftSummaryLastEditingLabel(String? lastEditingStep) {
    final s = lastEditingStep?.trim() ?? '';
    if (s.isEmpty) return '';
    return switch (s) {
      'vocabulary_kanji' => 'Vocabulary & Kanji',
      'grammar' => 'Grammar',
      'quiz' => 'Quiz',
      'audio' => 'Listening / Audio',
      _ => '',
    };
  }

  /// Add tab + list readiness line when [completionPercent] is present.
  static String draftSummaryReadinessLine({
    int? completionPercent,
    required int sentenceCount,
  }) {
    if (completionPercent != null) {
      return '$completionPercent% complete';
    }
    if (sentenceCount > 0) {
      return '$sentenceCount sentences';
    }
    return 'Draft';
  }
}
