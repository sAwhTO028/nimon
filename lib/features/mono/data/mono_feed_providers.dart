import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/mono/data/remote_following_mono_feed_repository.dart';
import 'package:nimon/features/mono/data/remote_mono_feed_repository.dart';
import 'package:nimon/features/mono/data/remote_mono_social_repository.dart';
import 'package:nimon/features/profile/data/remote_user_follow_repository.dart';

/// Default remote Mono catalog repo (override in tests).
final remoteMonoFeedRepositoryProvider = Provider<MonoFeedRepository>((ref) {
  return RemoteMonoFeedRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

final remoteFollowingMonoFeedRepositoryProvider =
    Provider<MonoFeedRepository>((ref) {
  return RemoteFollowingMonoFeedRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

final remoteMonoSocialRepositoryProvider =
    Provider<RemoteMonoSocialRepository>((ref) {
  return RemoteMonoSocialRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

final remoteUserFollowRepositoryProvider =
    Provider<RemoteUserFollowRepository>((ref) {
  return RemoteUserFollowRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

final monoFeedPagerProvider =
    StateNotifierProvider<MonoFeedPager, PaginatedState<MonoFeedSummaryDto>>(
  (ref) => MonoFeedPager(ref.watch(remoteMonoFeedRepositoryProvider)),
);

final followingMonoFeedPagerProvider = StateNotifierProvider<
    FollowingMonoFeedPager, PaginatedState<MonoFeedSummaryDto>>(
  (ref) => FollowingMonoFeedPager(
    ref.watch(remoteFollowingMonoFeedRepositoryProvider),
  ),
);

/// Pager for `GET /v1/mono/feed`. Filters are optional (M3c can wire UI).
class MonoFeedPager extends StateNotifier<PaginatedState<MonoFeedSummaryDto>> {
  MonoFeedPager(this._repo)
      : super(const PaginatedState<MonoFeedSummaryDto>(
            items: <MonoFeedSummaryDto>[]));

  final MonoFeedRepository _repo;

  String? _filterLevel;
  String? _filterCategory;

  /// Updates facet filters for subsequent [loadFirstPage] / [refresh] / [loadMore].
  void setFilters({String? level, String? category}) {
    _filterLevel = level;
    _filterCategory = category;
  }

  Future<void> loadFirstPage() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isInitialLoading: true,
      isLoadingMore: false,
      error: null,
    );
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          limit: PaginationDefaults.monoFeedPageLimit,
          sort: 'recent',
        ),
        level: _filterLevel,
        category: _filterCategory,
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
    }
  }

  Future<void> refresh() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isRefreshing: true,
      isLoadingMore: false,
      nextCursor: null,
      error: null,
    );
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          limit: PaginationDefaults.monoFeedPageLimit,
          sort: 'recent',
        ),
        level: _filterLevel,
        category: _filterCategory,
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
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          cursor: cursor,
          limit: PaginationDefaults.monoFeedPageLimit,
          sort: 'recent',
        ),
        level: _filterLevel,
        category: _filterCategory,
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
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

/// Pager for `GET /v1/mono/feed?following=true` (auth required).
class FollowingMonoFeedPager
    extends StateNotifier<PaginatedState<MonoFeedSummaryDto>> {
  FollowingMonoFeedPager(this._repo)
      : super(const PaginatedState<MonoFeedSummaryDto>(
            items: <MonoFeedSummaryDto>[]));

  final MonoFeedRepository _repo;

  Future<void> loadFirstPage() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isInitialLoading: true,
      isLoadingMore: false,
      error: null,
    );
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          limit: PaginationDefaults.monoFeedPageLimit,
          sort: 'recent',
        ),
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
    }
  }

  Future<void> refresh() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isRefreshing: true,
      isLoadingMore: false,
      nextCursor: null,
      error: null,
    );
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          limit: PaginationDefaults.monoFeedPageLimit,
          sort: 'recent',
        ),
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
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          cursor: cursor,
          limit: PaginationDefaults.monoFeedPageLimit,
          sort: 'recent',
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
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
