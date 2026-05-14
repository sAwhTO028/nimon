import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_v1_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

CreatorStoryV1 _readOnlyReadyDraft(String owner) {
  final d = CreatorStoryV1.empty(creatorOwnerId: owner);
  final sid = d.id;
  return d.copyWith(
    basics: d.basics.copyWith(
      title: 'T',
      category: 'fiction',
      level: 'N4',
      description: 'Long enough description for basics.',
      targetDurationBandKey: '3_5',
      promptSourceNote: 'n',
    ),
    sentences: List.generate(
      8,
      (i) => StorySentenceItem(
        id: 's$i',
        storyId: sid,
        orderIndex: i,
        japaneseText: '雨が降る。',
      ),
    ),
  );
}

/// Throws published quota on read-only publish; otherwise echoes [fixed].
class _PublishQuotaRepo implements StoryDraftRepository {
  _PublishQuotaRepo(this.fixed);

  final CreatorStoryV1 fixed;

  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) async =>
      PageResult.empty();

  @override
  Future<void> clearActiveDraft() async {}

  @override
  Future<void> clearResumeMeta(String draftId) async {}

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteDraft(String draftId) async {}

  @override
  Future<bool> discardPublishedEditStaging(String draftId) async => false;

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) async {}

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async =>
      draft;

  @override
  Future<bool> hasAnyIndexedDraft() async => false;

  @override
  Future<bool> hasDraft(String draftId) async => false;

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() async => const [];

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) async =>
      draftId == fixed.id ? fixed : null;

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) async => null;

  @override
  Future<List<String>> listDraftIds() async => const [];

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) async {}

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async {
    if (remotePublishAfterPut == StoryDraftRemotePublishIntent.readOnly) {
      throw const AppQuotaExceededException(
        key: 'published_mono_limit_reached',
        limit: 30,
        current: 30,
      );
    }
    return draft;
  }

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) async => draft;

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {}

  @override
  Future<DateTime?> savedAt(String draftId) async => null;

  @override
  Future<DateTime?> savedAtActiveDraft() async => null;

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async {}
}

class _DraftQuotaRepo implements StoryDraftRepository {
  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) async =>
      PageResult.empty();

  @override
  Future<void> clearActiveDraft() async {}

  @override
  Future<void> clearResumeMeta(String draftId) async {}

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteDraft(String draftId) async {}

  @override
  Future<bool> discardPublishedEditStaging(String draftId) async => false;

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) async {}

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async =>
      draft;

  @override
  Future<bool> hasAnyIndexedDraft() async => false;

  @override
  Future<bool> hasDraft(String draftId) async => false;

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() async => const [];

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) async => null;

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) async => null;

  @override
  Future<List<String>> listDraftIds() async => const [];

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) async {}

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async {
    throw const AppQuotaExceededException(
      key: 'draft_story_limit_reached',
      limit: 50,
      current: 50,
    );
  }

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) async => draft;

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {}

  @override
  Future<DateTime?> savedAt(String draftId) async => null;

  @override
  Future<DateTime?> savedAtActiveDraft() async => null;

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('publishReadingOnlyToDisk restores publish state on quota', () async {
    final ready = _readOnlyReadyDraft('o');
    expect(computeReadOnlyReady(ready).ready, true);

    final n = StoryCreatorDraftNotifier(_PublishQuotaRepo(ready), 'o');
    await n.loadDraftById(ready.id, forceReloadFromDisk: true);
    expect(n.state.draft.publishState, StoryPublishState.draft);

    await expectLater(
      n.publishReadingOnlyToDisk(),
      throwsA(isA<AppQuotaExceededException>()),
    );
    expect(n.state.draft.publishState, StoryPublishState.draft);
    expect(n.state.saveStatus, CreatorDraftSaveStatus.idle);
  });

  test('applyBasicsAndWaitPersist surfaces draft quota', () async {
    final n = StoryCreatorDraftNotifier(_DraftQuotaRepo(), 'o');
    n.reset();
    await expectLater(
      n.applyBasicsAndWaitPersist(
        title: 'T',
        category: 'fiction',
        level: 'N4',
        description: 'D',
        promptSourceNote: '',
        coverImageUrl: null,
        targetDurationBandKey: '3_5',
      ),
      throwsA(isA<AppQuotaExceededException>()),
    );
    expect(n.state.saveStatus, CreatorDraftSaveStatus.failed);
  });
}
