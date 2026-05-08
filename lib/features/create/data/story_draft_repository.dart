import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Remote [StoryDraftRepository] only: after PUT, optionally chain Nest publish endpoints.
/// Plain edits use [StoryDraftRemotePublishIntent.none] so PublishedMono is not updated.
enum StoryDraftRemotePublishIntent { none, readOnly, fullLearn }

/// Persistence boundary for Add-flow story drafts (local today; swappable later).
abstract interface class StoryDraftRepository {
  /// New id, persisted immediately (same intent as [StoryCreatorDraftNotifier.startNewLocalDraft]).
  Future<CreatorStoryV1> createNewDraft({String? ownerId});

  Future<CreatorStoryV1?> loadDraft(String draftId);

  Future<List<CreatorStoryV1>> loadAllDrafts();

  Future<List<String>> listDraftIds();

  /// Cursor-paged draft summaries for Workspace / Processing lists (no full story bodies).
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
      PageRequest request);

  /// Bumps [StoryBasics.updatedAt], writes draft JSON, then touches resume `lastEditedAtUtc`.
  /// Returns the aggregate actually written (including the new [StoryBasics.updatedAt]).
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  });

  /// Local-only flush alias; same semantics as [saveDraft] until a queue exists.
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft);

  /// Flush the draft so Profile > Processing (and resume) reflect the latest state.
  ///
  /// This is a *local persistence* operation (and may be remote-backed depending on
  /// implementation), but it must not change storage structure. It is intended to
  /// be called by centralized back/exit logic.
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  });

  Future<void> deleteDraft(String draftId);

  /// Clears the **active** draft when no id is passed to storage — matches
  /// [StoryCreatorDraftStorage.clear] with no [draftId] (does not clear resume meta).
  Future<void> clearActiveDraft();

  Future<DateTime?> savedAt(String draftId);

  /// Whether the draft index is non-empty (same as [StoryCreatorDraftStorage.exists]).
  Future<bool> hasAnyIndexedDraft();

  /// [StoryCreatorDraftStorage.loadSavedAt] with no id — uses active draft id in prefs.
  Future<DateTime?> savedAtActiveDraft();

  Future<bool> hasDraft(String draftId);

  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId);

  /// Default resume meta if missing ([StoryCreatorDraftResumeStorage.ensureInit]).
  Future<void> ensureResumeMetaInitialized(String draftId);

  /// Last navigation for resume ([StoryCreatorDraftResumeStorage.recordLastActive]).
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  });

  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta);

  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  });

  Future<void> clearResumeMeta(String draftId);
}
