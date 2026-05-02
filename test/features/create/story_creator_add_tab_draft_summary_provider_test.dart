import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/presentation/providers/story_creator_add_tab_draft_summary_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';

DraftListSummaryDto _summary(String id) {
  return DraftListSummaryDto(
    draftId: id,
    title: 'T',
    coverImageUrl: null,
    level: 'n5',
    category: 'drama',
    status: 'draft',
    publishState: StoryPublishState.draft.storageKey,
    processingStatus: null,
    updatedAt: '2026-01-01T00:00:00.000Z',
    sentenceCount: 1,
    publishType: 'draft',
    previewText: 'p',
  );
}

class _SpyDraftRepo implements StoryDraftRepository {
  _SpyDraftRepo(this._onFetch);

  final Future<PageResult<DraftListSummaryDto>> Function(PageRequest r)
      _onFetch;

  PageRequest? lastPageRequest;

  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) {
    lastPageRequest = request;
    return _onFetch(request);
  }

  @override
  Future<void> clearActiveDraft() => throw StateError('loadDraft');

  @override
  Future<void> clearResumeMeta(String draftId) => throw StateError('loadDraft');

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) =>
      throw StateError('loadDraft');

  @override
  Future<void> deleteDraft(String draftId) => throw StateError('loadDraft');

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) =>
      throw StateError('loadDraft');

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      throw StateError('loadDraft');

  @override
  Future<bool> hasAnyIndexedDraft() => throw StateError('loadDraft');

  @override
  Future<bool> hasDraft(String draftId) => throw StateError('loadDraft');

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() => throw StateError('loadDraft');

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) =>
      throw StateError('loadDraft');

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) =>
      throw StateError('loadDraft');

  @override
  Future<List<String>> listDraftIds() => throw StateError('loadDraft');

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) =>
      throw StateError('loadDraft');

  @override
  Future<CreatorStoryV1> saveDraft(CreatorStoryV1 draft) =>
      throw StateError('loadDraft');

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) =>
      throw StateError('loadDraft');

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) =>
      throw StateError('loadDraft');

  @override
  Future<DateTime?> savedAt(String draftId) => throw StateError('loadDraft');

  @override
  Future<DateTime?> savedAtActiveDraft() => throw StateError('loadDraft');

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      throw StateError('loadDraft');
}

void main() {
  group('StoryCreatorAddTabDraftSummaryNotifier', () {
    test('fetch uses publishState=draft and limit 4', () async {
      final spy = _SpyDraftRepo((r) async {
        return PageResult<DraftListSummaryDto>(
          items: [_summary('1')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = StoryCreatorAddTabDraftSummaryNotifier(spy);
      await n.loadInitial();
      expect(spy.lastPageRequest, isNotNull);
      expect(spy.lastPageRequest!.publishState,
          StoryPublishState.draft.storageKey);
      expect(spy.lastPageRequest!.limit, kStoryCreatorAddTabDraftSummaryLimit);
    });

    test('first summary is Continue Working; next up to 3 are in-progress pool',
        () async {
      final spy = _SpyDraftRepo((_) async {
        return PageResult<DraftListSummaryDto>(
          items: [
            _summary('a'),
            _summary('b'),
            _summary('c'),
            _summary('d'),
          ],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = StoryCreatorAddTabDraftSummaryNotifier(spy);
      await n.loadInitial();
      expect(n.state.items, hasLength(4));
      expect(n.state.items.first.draftId, 'a');
      expect(
          n.state.items.map((e) => e.draftId).toList(), ['a', 'b', 'c', 'd']);
    });

    test('does not call loadDraft — spy throws if invoked', () async {
      final spy = _SpyDraftRepo((_) async {
        return PageResult<DraftListSummaryDto>(
          items: [_summary('x')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = StoryCreatorAddTabDraftSummaryNotifier(spy);
      await n.loadInitial();
      expect(n.state.items.single.draftId, 'x');
    });
  });
}
