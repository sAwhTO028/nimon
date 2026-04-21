import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Thin adapter over [StoryCreatorDraftStorage] + [StoryCreatorDraftResumeStorage].
class LocalStoryDraftRepository implements StoryDraftRepository {
  const LocalStoryDraftRepository();

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) async {
    final draft = CreatorStoryV1.empty(creatorOwnerId: ownerId ?? '');
    await StoryCreatorDraftResumeStorage.saveMeta(
      CreatorDraftResumeMeta.initial(
        draftId: draft.id,
        module: CreatorLastActiveModule.storyBasics,
      ),
    );
    final now = DateTime.now();
    final toPersist = draft.copyWith(
      basics: draft.basics.copyWith(updatedAt: now),
    );
    await StoryCreatorDraftStorage.save(toPersist);
    await StoryCreatorDraftResumeStorage.touchEdited(
      draftId: toPersist.id,
      atUtc: DateTime.now().toUtc(),
    );
    return toPersist;
  }

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) =>
      StoryCreatorDraftStorage.load(draftId: draftId);

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() =>
      StoryCreatorDraftStorage.loadAllDrafts();

  @override
  Future<List<String>> listDraftIds() => StoryCreatorDraftStorage.loadAllIds();

  @override
  Future<CreatorStoryV1> saveDraft(CreatorStoryV1 draft) async {
    final now = DateTime.now();
    final next = draft.copyWith(
      basics: draft.basics.copyWith(updatedAt: now),
    );
    await StoryCreatorDraftStorage.save(next);
    await StoryCreatorDraftResumeStorage.touchEdited(
      draftId: next.id,
      atUtc: DateTime.now().toUtc(),
    );
    return next;
  }

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) => saveDraft(draft);

  @override
  Future<void> deleteDraft(String draftId) async {
    await StoryCreatorDraftStorage.clear(draftId: draftId);
    await StoryCreatorDraftResumeStorage.clearMeta(draftId);
  }

  @override
  Future<void> clearActiveDraft() => StoryCreatorDraftStorage.clear();

  @override
  Future<DateTime?> savedAt(String draftId) =>
      StoryCreatorDraftStorage.loadSavedAt(draftId: draftId);

  @override
  Future<bool> hasAnyIndexedDraft() async =>
      (await listDraftIds()).isNotEmpty;

  @override
  Future<DateTime?> savedAtActiveDraft() =>
      StoryCreatorDraftStorage.loadSavedAt();

  @override
  Future<bool> hasDraft(String draftId) =>
      StoryCreatorDraftStorage.hasDraft(draftId);

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) =>
      StoryCreatorDraftResumeStorage.loadMeta(draftId);

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) =>
      StoryCreatorDraftResumeStorage.ensureInit(draftId);

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) =>
      StoryCreatorDraftResumeStorage.recordLastActive(
        draftId: draftId,
        module: module,
        subPage: subPage,
      );

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) =>
      StoryCreatorDraftResumeStorage.saveMeta(meta);

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) return;

    if (lastActiveModule != null || lastActiveSubPage != null) {
      final existing = await StoryCreatorDraftResumeStorage.loadMeta(id);
      final module = lastActiveModule ??
          existing?.lastActiveModule ??
          CreatorLastActiveModule.storyBasics;
      await StoryCreatorDraftResumeStorage.recordLastActive(
        draftId: id,
        module: module,
        subPage: lastActiveSubPage,
      );
    }
    if (touchEditedAtUtc != null) {
      await StoryCreatorDraftResumeStorage.touchEdited(
        draftId: id,
        atUtc: touchEditedAtUtc,
      );
    }
  }

  @override
  Future<void> clearResumeMeta(String draftId) =>
      StoryCreatorDraftResumeStorage.clearMeta(draftId);
}
