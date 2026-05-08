import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/creator_drawer_publish_labels.dart';
import 'package:nimon/features/create/creator_published_edit_baseline.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/features/create/story_v1_model.dart';

CreatorStoryV1 _minimalDraft({
  StoryPublishState publishState = StoryPublishState.draft,
  bool? hasUnpublishedCoreChanges,
}) {
  return CreatorStoryV1.empty().copyWith(
    publishState: publishState,
    hasUnpublishedCoreChanges: hasUnpublishedCoreChanges,
  );
}

StoryReviewDisplayModel _readyModel() {
  const ok = CreatorReadinessResult(ready: true, unmetMessages: []);
  return const StoryReviewDisplayModel(
    isStoryCoreReady: true,
    isReadingOnlyReady: true,
    isFullLearnReady: true,
    completedLearnModuleCount: 4,
    totalLearnModuleCount: kStoryReviewLearnModuleTotal,
    readOnly: ok,
    fullLearn: ok,
  );
}

void main() {
  group('creatorProgressDrawerPublishPrimaryLabel', () {
    test('unpublished read-only path shows Publish', () {
      expect(
        creatorProgressDrawerPublishPrimaryLabel(
          learnModeEnabled: false,
          readOnlyPublishedExists: false,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: false,
          fullLearnHasUnpublishedChanges: false,
        ),
        'Read Only Publish',
      );
    });

    test('published read-only + dirty shows Update Read Only', () {
      expect(
        creatorProgressDrawerPublishPrimaryLabel(
          learnModeEnabled: false,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: true,
          fullLearnPublishedExists: false,
          fullLearnHasUnpublishedChanges: false,
        ),
        'Update Read Only',
      );
    });

    test('published read-only + clean shows Read Only Published', () {
      expect(
        creatorProgressDrawerPublishPrimaryLabel(
          learnModeEnabled: false,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: false,
          fullLearnHasUnpublishedChanges: false,
        ),
        'Read Only Published',
      );
    });

    test('first full learn (RO exists but FL not) shows Full Learn Publish',
        () {
      expect(
        creatorProgressDrawerPublishPrimaryLabel(
          learnModeEnabled: true,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: false,
          fullLearnHasUnpublishedChanges: false,
        ),
        'Full Learn Publish',
      );
    });

    test('published full learn + dirty shows Update Full Learn', () {
      expect(
        creatorProgressDrawerPublishPrimaryLabel(
          learnModeEnabled: true,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: true,
          fullLearnHasUnpublishedChanges: true,
        ),
        'Update Full Learn',
      );
    });

    test('published full learn + clean shows Full Learn Published', () {
      expect(
        creatorProgressDrawerPublishPrimaryLabel(
          learnModeEnabled: true,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: true,
          fullLearnHasUnpublishedChanges: false,
        ),
        'Full Learn Published',
      );
    });
  });

  group('computeReadOnlyHasUnpublishedChanges', () {
    test('local dirty wins over server hasUnpublishedCoreChanges false', () {
      final d = _minimalDraft(
        publishState: StoryPublishState.readingOnlyPublished,
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeReadOnlyHasUnpublishedChanges(
          draft: d,
          readOnlyPublishedCoreSig: 'sig',
          dirty: true,
        ),
        true,
      );
    });

    test('server true enables while dirty false', () {
      final d = _minimalDraft(
        publishState: StoryPublishState.readingOnlyPublished,
        hasUnpublishedCoreChanges: true,
      );
      expect(
        computeReadOnlyHasUnpublishedChanges(
          draft: d,
          readOnlyPublishedCoreSig: 'sig',
          dirty: false,
        ),
        true,
      );
    });

    test('server false and clean disables', () {
      final d = _minimalDraft(
        publishState: StoryPublishState.readingOnlyPublished,
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeReadOnlyHasUnpublishedChanges(
          draft: d,
          readOnlyPublishedCoreSig: null,
          dirty: false,
        ),
        false,
      );
    });
  });

  group('computeFullLearnHasUnpublishedChanges', () {
    test('uses server true after save (dirty cleared)', () {
      final d = _minimalDraft(
        publishState: StoryPublishState.fullLearnPublished,
        hasUnpublishedCoreChanges: true,
      );
      expect(
        computeFullLearnHasUnpublishedChanges(
          draft: d,
          readOnlyPublishedCoreSig: 'sig',
          dirty: false,
        ),
        true,
      );
    });

    test('server false relies on dirty for learn-only edits', () {
      final d = _minimalDraft(
        publishState: StoryPublishState.fullLearnPublished,
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeFullLearnHasUnpublishedChanges(
          draft: d,
          readOnlyPublishedCoreSig: 'sig',
          dirty: true,
        ),
        true,
      );
      expect(
        computeFullLearnHasUnpublishedChanges(
          draft: d,
          readOnlyPublishedCoreSig: null,
          dirty: false,
        ),
        false,
      );
    });

    test('v2 full-learn baseline detects learn change without dirty or server',
        () {
      final d0 = _minimalDraft(
        publishState: StoryPublishState.fullLearnPublished,
        hasUnpublishedCoreChanges: false,
      );
      final flBase = computeFullLearnEditBaselineSignature(d0);
      final d1 = d0.copyWith(
        vocabularyKanji: VocabularyKanjiLayer(
          entries: [
            VocabularyKanjiEntry(
              id: 'v1',
              termJapanese: '犬',
              type: VocabularyKanjiEntryType.vocabulary,
            ),
          ],
        ),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeFullLearnHasUnpublishedChanges(
          draft: d1,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig:
              computeReadOnlyEditBaselineSignature(d0),
          publishedEditFullLearnBaselineSig: flBase,
        ),
        true,
      );
    });
  });

  group('computeReadOnlyHasUnpublishedChanges baseline integration', () {
    test('v2 read-only baseline detects title change without dirty or server',
        () {
      final d0 = _minimalDraft(
        publishState: StoryPublishState.readingOnlyPublished,
        hasUnpublishedCoreChanges: false,
      );
      final b = computeReadOnlyEditBaselineSignature(d0);
      final d1 = d0.copyWith(
        basics: d0.basics.copyWith(title: 'Changed'),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeReadOnlyHasUnpublishedChanges(
          draft: d1,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig: b,
        ),
        true,
      );
    });
  });

  group('creatorProgressDrawerPublishHelperText', () {
    test('enabled update shows workspace hint when saved', () {
      expect(
        creatorProgressDrawerPublishHelperText(
          learnModeEnabled: true,
          publishEnabled: true,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: true,
          fullLearnHasUnpublishedChanges: true,
          hasLocalUnsavedEdits: false,
          publishModel: _readyModel(),
        ),
        'Changes are saved in Workspace. Update to publish them.',
      );
    });

    test('enabled update shows save-first when local dirty', () {
      expect(
        creatorProgressDrawerPublishHelperText(
          learnModeEnabled: false,
          publishEnabled: true,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: true,
          fullLearnPublishedExists: false,
          fullLearnHasUnpublishedChanges: false,
          hasLocalUnsavedEdits: true,
          publishModel: _readyModel(),
        ),
        'Save changes, then update the published version.',
      );
    });

    test('disabled up-to-date full learn', () {
      expect(
        creatorProgressDrawerPublishHelperText(
          learnModeEnabled: true,
          publishEnabled: false,
          readOnlyPublishedExists: true,
          readOnlyHasUnpublishedChanges: false,
          fullLearnPublishedExists: true,
          fullLearnHasUnpublishedChanges: false,
          hasLocalUnsavedEdits: false,
          publishModel: _readyModel(),
        ),
        'Published version is up to date.',
      );
    });
  });
}
