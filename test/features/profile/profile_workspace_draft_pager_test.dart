import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_workspace_draft_pager.dart';

DraftListSummaryDto _row(String id) {
  return DraftListSummaryDto(
    draftId: id,
    title: 'T $id',
    coverImageUrl: null,
    level: 'n5',
    category: 'drama',
    status: 'draft',
    publishState: StoryPublishState.draft.storageKey,
    processingStatus: null,
    updatedAt: '2026-01-01T00:00:00.000Z',
    sentenceCount: 1,
    publishType: 'draft',
    previewText: 'x',
  );
}

/// Test double: only [fetchWorkspaceDraftPage] is exercised.
class _StubWorkspaceDraftRepository implements StoryDraftRepository {
  _StubWorkspaceDraftRepository(this._fetch);

  final Future<PageResult<DraftListSummaryDto>> Function(PageRequest r) _fetch;

  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) =>
      _fetch(request);

  @override
  Future<void> clearActiveDraft() => throw UnimplementedError();

  @override
  Future<void> clearResumeMeta(String draftId) => throw UnimplementedError();

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteDraft(String draftId) => throw UnimplementedError();

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) =>
      throw UnimplementedError();

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      throw UnimplementedError();

  @override
  Future<bool> hasAnyIndexedDraft() => throw UnimplementedError();

  @override
  Future<bool> hasDraft(String draftId) => throw UnimplementedError();

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() => throw UnimplementedError();

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) =>
      throw UnimplementedError();

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) =>
      throw UnimplementedError();

  @override
  Future<List<String>> listDraftIds() => throw UnimplementedError();

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) =>
      throw UnimplementedError();

  @override
  Future<CreatorStoryV1> saveDraft(CreatorStoryV1 draft) =>
      throw UnimplementedError();

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) =>
      throw UnimplementedError();

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) =>
      throw UnimplementedError();

  @override
  Future<DateTime?> savedAt(String draftId) => throw UnimplementedError();

  @override
  Future<DateTime?> savedAtActiveDraft() => throw UnimplementedError();

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('ProfileWorkspaceDraftPager', () {
    test('loadFirstPage loads items', () async {
      final stub = _StubWorkspaceDraftRepository((_) async {
        return PageResult<DraftListSummaryDto>(
          items: [_row('a')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final pager = ProfileWorkspaceDraftPager(stub);
      await pager.loadFirstPage();
      expect(pager.state.items, hasLength(1));
      expect(pager.state.items.single.draftId, 'a');
      expect(pager.state.isInitialLoading, isFalse);
      expect(pager.state.hasMore, isFalse);
    });

    test('loadMore appends when hasMore', () async {
      final second = _row('b');
      var calls = 0;
      final stub = _StubWorkspaceDraftRepository((r) async {
        calls++;
        if (calls == 1) {
          expect(r.cursor, isNull);
          expect(r.limit, PaginationDefaults.workspacePageLimit);
          return PageResult<DraftListSummaryDto>(
            items: [_row('a')],
            nextCursor: 'c2',
            hasMore: true,
          );
        }
        expect(r.cursor, 'c2');
        return PageResult<DraftListSummaryDto>(
          items: [second],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfileWorkspaceDraftPager(stub);
      await n.loadFirstPage();
      await n.loadMore();
      expect(n.state.items.map((e) => e.draftId).toList(), ['a', 'b']);
      expect(n.state.hasMore, isFalse);
      expect(calls, 2);
    });

    test('loadMore is a no-op when hasMore is false', () async {
      var calls = 0;
      final stub = _StubWorkspaceDraftRepository((_) async {
        calls++;
        return PageResult<DraftListSummaryDto>(
          items: [_row('a')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfileWorkspaceDraftPager(stub);
      await n.loadFirstPage();
      await n.loadMore();
      expect(calls, 1);
    });

    test('refresh replaces rows', () async {
      var calls = 0;
      final stub = _StubWorkspaceDraftRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<DraftListSummaryDto>(
            items: [_row('a')],
            nextCursor: 'old',
            hasMore: true,
          );
        }
        expect(r.cursor, isNull);
        return PageResult<DraftListSummaryDto>(
          items: [_row('x')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfileWorkspaceDraftPager(stub);
      await n.loadFirstPage();
      expect(n.state.nextCursor, 'old');
      await n.refresh();
      expect(n.state.items.single.draftId, 'x');
      expect(n.state.nextCursor, isNull);
      expect(calls, 2);
    });

    test('stale loadMore ignored after refresh bumps epoch', () async {
      final hold = Completer<void>();
      var calls = 0;
      final stub = _StubWorkspaceDraftRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<DraftListSummaryDto>(
            items: [_row('a')],
            nextCursor: 'c1',
            hasMore: true,
          );
        }
        if (calls == 2) {
          await hold.future;
          return PageResult<DraftListSummaryDto>(
            items: [_row('stale')],
            nextCursor: null,
            hasMore: false,
          );
        }
        return PageResult<DraftListSummaryDto>(
          items: [_row('fresh')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfileWorkspaceDraftPager(stub);
      await n.loadFirstPage();
      expect(calls, 1);
      final slowMore = n.loadMore();
      await n.refresh();
      hold.complete();
      await slowMore;
      await pumpEventQueue();
      expect(n.state.items.single.draftId, 'fresh');
      expect(n.state.isLoadingMore, isFalse);
    });

    test('removeDraftById / removeDraftsByIds', () async {
      final stub = _StubWorkspaceDraftRepository((_) async {
        return PageResult<DraftListSummaryDto>(
          items: [_row('a'), _row('b'), _row('c')],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfileWorkspaceDraftPager(stub);
      await n.loadFirstPage();
      n.removeDraftById('b');
      expect(n.state.items.map((e) => e.draftId).toList(), ['a', 'c']);
      n.removeDraftsByIds({'a', 'c'});
      expect(n.state.items, isEmpty);
    });
  });
}
