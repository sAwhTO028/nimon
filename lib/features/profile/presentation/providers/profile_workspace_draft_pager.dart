import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';

/// Default repository comes from [storyDraftRepositoryProvider].
final profileWorkspaceDraftPagerProvider = StateNotifierProvider<
    ProfileWorkspaceDraftPager, PaginatedState<DraftListSummaryDto>>((ref) {
  return ProfileWorkspaceDraftPager(ref.watch(storyDraftRepositoryProvider));
});

class ProfileWorkspaceDraftPager
    extends StateNotifier<PaginatedState<DraftListSummaryDto>> {
  ProfileWorkspaceDraftPager(this._repo)
      : super(
          const PaginatedState<DraftListSummaryDto>(
            items: <DraftListSummaryDto>[],
          ),
        );

  final StoryDraftRepository _repo;

  Future<void> loadFirstPage() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isInitialLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      error: null,
    );
    try {
      final result = await _repo.fetchWorkspaceDraftPage(
        PageRequest(limit: PaginationDefaults.workspacePageLimit),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isInitialLoading: false,
        error: null,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        isInitialLoading: false,
        error: e,
      );
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isInitialLoading: false);
      }
    }
  }

  Future<void> refresh() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isRefreshing: true,
      isInitialLoading: false,
      isLoadingMore: false,
      nextCursor: null,
      error: null,
    );
    try {
      final result = await _repo.fetchWorkspaceDraftPage(
        PageRequest(limit: PaginationDefaults.workspacePageLimit),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        isRefreshing: false,
        error: e,
      );
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isRefreshing: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchWorkspaceDraftPage(
        PageRequest(
          cursor: cursor,
          limit: PaginationDefaults.workspacePageLimit,
        ),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        error: null,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(error: e);
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  void removeDraftById(String draftId) {
    removeDraftsByIds({draftId});
  }

  void removeDraftsByIds(Set<String> draftIds) {
    if (draftIds.isEmpty) return;
    final trimmed =
        draftIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      items: [
        for (final e in state.items)
          if (!trimmed.contains(e.draftId.trim())) e,
      ],
    );
  }
}
