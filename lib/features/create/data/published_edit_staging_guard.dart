import 'package:nimon/features/create/story_creator_models.dart';

/// True when [draft] is an unpublished edit session linked to an existing
/// published mono (Workspace "Editing • Previously published").
///
/// Used to gate [StoryDraftRepository.discardPublishedEditStaging] so plain
/// local drafts cannot be removed through that API by mistake.
bool isLinkedPublishedEditStagingDraft(CreatorStoryV1? draft) {
  if (draft == null) return false;
  if (draft.publishState == StoryPublishState.draft) return false;
  final pm = draft.publishedMonoId?.trim() ?? '';
  return pm.isNotEmpty;
}
