import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';
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
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});

final remoteMonoSocialRepositoryProvider =
    Provider<RemoteMonoSocialRepository>((ref) {
  return RemoteMonoSocialRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});

final remoteUserFollowRepositoryProvider =
    Provider<RemoteUserFollowRepository>((ref) {
  return RemoteUserFollowRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});

final monoFeedPagerProvider =
    StateNotifierProvider<MonoFeedPager, PaginatedState<MonoFeedSummaryDto>>(
  (ref) => MonoFeedPager(
    ref.watch(remoteMonoFeedRepositoryProvider),
    catalogLens: () => CatalogDiscoveryLens.tryFromPreferences(
      ref.read(userPreferencesNotifierProvider).prefs,
    ),
  ),
);

final followingMonoFeedPagerProvider = StateNotifierProvider<
    FollowingMonoFeedPager, PaginatedState<MonoFeedSummaryDto>>(
  (ref) => FollowingMonoFeedPager(
    ref.watch(remoteFollowingMonoFeedRepositoryProvider),
    catalogLens: () => CatalogDiscoveryLens.tryFromPreferences(
      ref.read(userPreferencesNotifierProvider).prefs,
    ),
  ),
);

/// M11g: Reels pagination policy (see docs/M11_SETTINGS_FOUNDATION_DECISION_SPEC.md).
abstract final class MonoReelsPaginationPolicy {
  static const int initialLimit = 7;
  static const int nextLimit = 10;
  static const int prefetchRemainingThreshold = 3;
}

/// Pager for `GET /v1/mono/feed`. Filters are optional (M3c can wire UI).
typedef CatalogDiscoveryLensReader = CatalogDiscoveryLens? Function();

class MonoFeedPager extends StateNotifier<PaginatedState<MonoFeedSummaryDto>> {
  MonoFeedPager(
    this._repo, {
    CatalogDiscoveryLensReader? catalogLens,
  })  : _catalogLens = catalogLens ?? (() => null),
        super(const PaginatedState<MonoFeedSummaryDto>(
            items: <MonoFeedSummaryDto>[]));

  final MonoFeedRepository _repo;
  final CatalogDiscoveryLensReader _catalogLens;

  String? _filterLevel;
  String? _filterCategory;

  String? _lastLoadMoreCursor;

  /// Updates facet filters for subsequent [loadFirstPage] / [refresh] / [loadMore].
  void setFilters({String? level, String? category}) {
    _filterLevel = level;
    _filterCategory = category;
  }

  /// Called from the reels UI on index changes to prefetch the next page.
  ///
  /// Policy:
  /// - prefetch when remaining <= 3
  /// - never prefetch while busy
  /// - avoid re-requesting the same cursor repeatedly
  void maybePrefetch(int currentIndex) {
    final remaining = state.items.length - currentIndex - 1;
    if (remaining > MonoReelsPaginationPolicy.prefetchRemainingThreshold) {
      return;
    }
    if (!state.canLoadMore) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;
    if (_lastLoadMoreCursor == cursor) return;
    _lastLoadMoreCursor = cursor;
    unawaited(loadMore());
  }

  Future<void> loadFirstPage() async {
    _lastLoadMoreCursor = null;
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
          limit: MonoReelsPaginationPolicy.initialLimit,
          sort: 'recent',
        ),
        level: _filterLevel,
        category: _filterCategory,
        catalogLens: _catalogLens(),
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
    _lastLoadMoreCursor = null;
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
          limit: MonoReelsPaginationPolicy.initialLimit,
          sort: 'recent',
        ),
        level: _filterLevel,
        category: _filterCategory,
        catalogLens: _catalogLens(),
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
    if (cursor == null || cursor.isEmpty) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          cursor: cursor,
          limit: MonoReelsPaginationPolicy.nextLimit,
          sort: 'recent',
        ),
        level: _filterLevel,
        category: _filterCategory,
        catalogLens: _catalogLens(),
      );
      if (state.requestEpoch != myEpoch) return;
      final seen = <String>{for (final it in state.items) it.monoId};
      final appended = <MonoFeedSummaryDto>[
        ...state.items,
        ...result.items.where((it) => seen.add(it.monoId)),
      ];
      state = state.copyWith(
        items: appended,
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
  FollowingMonoFeedPager(
    this._repo, {
    CatalogDiscoveryLensReader? catalogLens,
  })  : _catalogLens = catalogLens ?? (() => null),
        super(const PaginatedState<MonoFeedSummaryDto>(
            items: <MonoFeedSummaryDto>[]));

  final MonoFeedRepository _repo;
  final CatalogDiscoveryLensReader _catalogLens;

  String? _lastLoadMoreCursor;

  void maybePrefetch(int currentIndex) {
    final remaining = state.items.length - currentIndex - 1;
    if (remaining > MonoReelsPaginationPolicy.prefetchRemainingThreshold) {
      return;
    }
    if (!state.canLoadMore) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;
    if (_lastLoadMoreCursor == cursor) return;
    _lastLoadMoreCursor = cursor;
    unawaited(loadMore());
  }

  Future<void> loadFirstPage() async {
    _lastLoadMoreCursor = null;
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
          limit: MonoReelsPaginationPolicy.initialLimit,
          sort: 'recent',
        ),
        catalogLens: _catalogLens(),
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
    _lastLoadMoreCursor = null;
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
          limit: MonoReelsPaginationPolicy.initialLimit,
          sort: 'recent',
        ),
        catalogLens: _catalogLens(),
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
    if (cursor == null || cursor.isEmpty) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchFeedPage(
        PageRequest(
          cursor: cursor,
          limit: MonoReelsPaginationPolicy.nextLimit,
          sort: 'recent',
        ),
        catalogLens: _catalogLens(),
      );
      if (state.requestEpoch != myEpoch) return;
      final seen = <String>{for (final it in state.items) it.monoId};
      final appended = <MonoFeedSummaryDto>[
        ...state.items,
        ...result.items.where((it) => seen.add(it.monoId)),
      ];
      state = state.copyWith(
        items: appended,
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
