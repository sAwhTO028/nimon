import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/remote_mono_social_repository.dart';

final profileSavedMonoPagerProvider =
    StateNotifierProvider<ProfileSavedMonoPager, PaginatedState<MonoFeedItem>>(
  (ref) => ProfileSavedMonoPager(ref.watch(remoteMonoSocialRepositoryProvider)),
);

/// Profile Saved tab (`GET /v1/me/bookmarks`), newest-first cursor paging.
class ProfileSavedMonoPager
    extends StateNotifier<PaginatedState<MonoFeedItem>> {
  ProfileSavedMonoPager(this._repo)
      : super(const PaginatedState<MonoFeedItem>(items: <MonoFeedItem>[]));

  final RemoteMonoSocialRepository _repo;

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
      final result = await _repo.fetchBookmarkedPage(
        PageRequest(limit: PaginationDefaults.profilePageLimit),
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
      state = state.copyWith(isInitialLoading: false, error: e);
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
      final result = await _repo.fetchBookmarkedPage(
        PageRequest(limit: PaginationDefaults.profilePageLimit),
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
      state = state.copyWith(isRefreshing: false, error: e);
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
      final result = await _repo.fetchBookmarkedPage(
        PageRequest(cursor: cursor, limit: PaginationDefaults.profilePageLimit),
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

  void removeItemsByIds(Set<String> ids) {
    if (ids.isEmpty) return;
    state = state.copyWith(
      items: [
        for (final e in state.items)
          if (!ids.contains(e.id)) e,
      ],
    );
  }
}
