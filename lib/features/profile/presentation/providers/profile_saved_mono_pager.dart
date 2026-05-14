import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
    if (kDebugMode) {
      debugPrint('[SavedTab] loadFirst start');
    }
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
        totalCount: result.totalCount,
      );
      if (kDebugMode) {
        debugPrint(
          '[SavedTab] loadFirst end items=${result.items.length} '
          'hasMore=${result.hasMore} nextCursor=${result.nextCursor != null && result.nextCursor!.isNotEmpty} '
          'totalCount=${result.totalCount}',
        );
      }
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(isInitialLoading: false, error: e);
      if (kDebugMode) {
        debugPrint('[SavedTab] loadFirst error=$e');
      }
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
      hasMore: false,
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
        totalCount: result.totalCount,
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
    if (kDebugMode) {
      debugPrint(
        '[SavedTab] loadMore enter canLoadMore=${state.canLoadMore} '
        'hasMore=${state.hasMore} isLoadingMore=${state.isLoadingMore} '
        'nextCursor=${state.nextCursor != null && state.nextCursor!.isNotEmpty}',
      );
    }
    if (!state.canLoadMore) {
      if (kDebugMode) {
        debugPrint('[SavedTab] loadMore skip: !canLoadMore');
      }
      return;
    }
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    final oldLen = state.items.length;
    state = state.copyWith(isLoadingMore: true);
    if (kDebugMode) {
      debugPrint('[SavedTab] loadMore trigger oldLen=$oldLen');
    }
    try {
      final result = await _repo.fetchBookmarkedPage(
        PageRequest(cursor: cursor, limit: PaginationDefaults.profilePageLimit),
      );
      if (state.requestEpoch != myEpoch) return;
      final existingIds = state.items.map((e) => e.id).toSet();
      final appended = result.items
          .where((e) => !existingIds.contains(e.id))
          .toList(growable: false);
      state = state.copyWith(
        items: [...state.items, ...appended],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        error: null,
        totalCount: result.totalCount ?? state.totalCount,
      );
      if (kDebugMode) {
        debugPrint(
          '[SavedTab] append old=$oldLen new=${appended.length} '
          'total=${state.items.length} hasMore=${state.hasMore} '
          'nextCursor=${state.nextCursor != null && state.nextCursor!.isNotEmpty}',
        );
      }
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(error: e);
      if (kDebugMode) {
        debugPrint('[SavedTab] loadMore error=$e');
      }
    } finally {
      state = state.copyWith(isLoadingMore: false);
      if (kDebugMode) {
        debugPrint('[SavedTab] loadMore done isLoadingMore=false');
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
