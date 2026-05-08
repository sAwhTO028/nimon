import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:nimon/features/create/creator_published_edit_baseline.dart';
import 'package:nimon/features/create/creator_read_only_publish_tracking.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// True once Read Only has shipped at least once (local sig **or** publishState).
bool computeReadOnlyPublishedExists({
  required CreatorStoryV1 draft,
  required String? readOnlyPublishedCoreSig,
}) {
  final sig = readOnlyPublishedCoreSig?.trim();
  return (sig != null && sig.isNotEmpty) ||
      draft.publishState != StoryPublishState.draft;
}

/// Uses v2 baseline diff (basics + full sentence payloads), then dirty / server / legacy thin sig.
bool computeReadOnlyHasUnpublishedChanges({
  required CreatorStoryV1 draft,
  required String? readOnlyPublishedCoreSig,
  required bool dirty,
  String? publishedEditReadOnlyBaselineSig,
}) {
  return computeReadOnlyHasUnpublishedChangesWithBaseline(
    draft: draft,
    readOnlyPublishedCoreSig: readOnlyPublishedCoreSig,
    dirty: dirty,
    publishedEditReadOnlyBaselineSig: publishedEditReadOnlyBaselineSig,
  );
}

bool computeFullLearnHasUnpublishedChanges({
  required CreatorStoryV1 draft,
  required String? readOnlyPublishedCoreSig,
  required bool dirty,
  String? publishedEditReadOnlyBaselineSig,
  String? publishedEditFullLearnBaselineSig,
}) {
  return computeFullLearnHasUnpublishedChangesWithBaseline(
    draft: draft,
    readOnlyPublishedCoreSig: readOnlyPublishedCoreSig,
    dirty: dirty,
    publishedEditReadOnlyBaselineSig: publishedEditReadOnlyBaselineSig,
    publishedEditFullLearnBaselineSig: publishedEditFullLearnBaselineSig,
  );
}

String _sigPreview(String? s, [int max = 10]) {
  final t = s?.trim() ?? '';
  if (t.isEmpty) return '';
  return t.length <= max ? t : t.substring(0, max);
}

/// `kDebugMode` only: one-line trace for publish drawer / staging diagnosis.
void debugTraceCreatorDrawerPublish({
  required String surface,
  required CreatorStoryV1 draft,
  required bool localDirty,
  required String? readOnlyPublishedCoreSig,
  required String? publishedEditReadOnlyBaselineSig,
  required String? publishedEditFullLearnBaselineSig,
  required bool learnModeEnabled,
  required bool readOnlyPublishedExists,
  required bool readOnlyHasUnpublishedChanges,
  required bool fullLearnPublishedExists,
  required bool fullLearnHasUnpublishedChanges,
  required bool publishEnabled,
  required String publishDisabledReason,
  required String publishLabel,
  required String? helperText,
}) {
  if (!kDebugMode) return;
  final curRo = computeReadOnlyEditBaselineSignature(draft);
  final curFl = computeFullLearnEditBaselineSignature(draft);
  final roBase = publishedEditReadOnlyBaselineSig?.trim();
  final flBase = publishedEditFullLearnBaselineSig?.trim();
  final roDiff =
      roBase != null && roBase.isNotEmpty && curRo != roBase ? true : false;
  final flDiff =
      flBase != null && flBase.isNotEmpty && curFl != flBase ? true : false;
  final thinLegacy = readOnlyPublishedCoreSig?.trim();
  final sigDirtyThin = thinLegacy != null &&
      thinLegacy.isNotEmpty &&
      computeReadOnlyPublishedCoreSignature(draft) != thinLegacy;
  debugPrint(
    '[creator_drawer_publish] surface=$surface '
    'draftId=${draft.id.trim()} '
    'publishState=${draft.publishState.storageKey} '
    'publishedMonoId=${draft.publishedMonoId ?? 'null'} '
    'hasUnpublishedCoreChanges=${draft.hasUnpublishedCoreChanges ?? 'null'} '
    'localDirty=$localDirty '
    'roBaseline=${_sigPreview(roBase)} roCur=${_sigPreview(curRo)} roDiff=$roDiff '
    'flBaseline=${_sigPreview(flBase)} flCur=${_sigPreview(curFl)} flDiff=$flDiff '
    'thinLegacyDiff=$sigDirtyThin '
    'learnMode=$learnModeEnabled '
    'roExists=$readOnlyPublishedExists roUnpub=$readOnlyHasUnpublishedChanges '
    'flExists=$fullLearnPublishedExists flUnpub=$fullLearnHasUnpublishedChanges '
    'publishEnabled=$publishEnabled reason=$publishDisabledReason '
    'label="$publishLabel" '
    'helper="${helperText ?? ''}"',
  );
}

/// Primary [FilledButton] label for the drawer publish action.
String creatorProgressDrawerPublishPrimaryLabel({
  required bool learnModeEnabled,
  required bool readOnlyPublishedExists,
  required bool readOnlyHasUnpublishedChanges,
  required bool fullLearnPublishedExists,
  required bool fullLearnHasUnpublishedChanges,
}) {
  if (!learnModeEnabled) {
    if (!readOnlyPublishedExists) return 'Read Only Publish';
    if (readOnlyHasUnpublishedChanges) return 'Update Read Only';
    return 'Read Only Published';
  }
  if (!fullLearnPublishedExists) return 'Full Learn Publish';
  if (fullLearnHasUnpublishedChanges) return 'Update Full Learn';
  return 'Full Learn Published';
}

/// Subtitle under the publish row (requirements, up-to-date, or workspace hint).
String? creatorProgressDrawerPublishHelperText({
  required bool learnModeEnabled,
  required bool publishEnabled,
  required bool readOnlyPublishedExists,
  required bool readOnlyHasUnpublishedChanges,
  required bool fullLearnPublishedExists,
  required bool fullLearnHasUnpublishedChanges,
  required bool hasLocalUnsavedEdits,
  required StoryReviewDisplayModel publishModel,
}) {
  if (publishEnabled) {
    final showWorkspaceHint = (!learnModeEnabled &&
            readOnlyPublishedExists &&
            readOnlyHasUnpublishedChanges) ||
        (learnModeEnabled &&
            fullLearnPublishedExists &&
            fullLearnHasUnpublishedChanges);
    if (showWorkspaceHint) {
      if (hasLocalUnsavedEdits) {
        return 'Save changes, then update the published version.';
      }
      return 'Changes are saved in Workspace. Update to publish them.';
    }
    return null;
  }
  if (!learnModeEnabled &&
      readOnlyPublishedExists &&
      !readOnlyHasUnpublishedChanges) {
    return 'Published version is up to date.';
  }
  if (learnModeEnabled &&
      fullLearnPublishedExists &&
      !fullLearnHasUnpublishedChanges) {
    return 'Published version is up to date.';
  }
  if (!learnModeEnabled) {
    return publishModel.isReadingOnlyReady
        ? null
        : 'Finish story basics and storytelling first.';
  }
  if (!publishModel.isReadingOnlyReady) {
    return 'Finish story basics and storytelling first.';
  }
  return 'Complete all Learn modules to publish Full Learn.';
}
