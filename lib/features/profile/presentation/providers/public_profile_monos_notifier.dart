import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';

const Object _unset = Object();

/// Paginated Monos list for [PublicProfileScreen] remote Monos tab (M14J-B).
@immutable
class PublicProfileMonosState {
  const PublicProfileMonosState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<MonoFeedItem> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get canLoadMore =>
      hasMore &&
      !isLoadingMore &&
      !isInitialLoading &&
      !isRefreshing &&
      (nextCursor != null && nextCursor!.trim().isNotEmpty);

  bool get showEmptyAfterLoad =>
      !isInitialLoading && !isRefreshing && items.isEmpty && error == null;

  PublicProfileMonosState copyWith({
    List<MonoFeedItem>? items,
    Object? nextCursor = _unset,
    bool? hasMore,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _unset,
    Object? loadMoreError = _unset,
  }) {
    return PublicProfileMonosState(
      items: items ?? this.items,
      nextCursor:
          nextCursor == _unset ? this.nextCursor : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == _unset ? this.error : error,
      loadMoreError:
          loadMoreError == _unset ? this.loadMoreError : loadMoreError,
    );
  }
}

/// Cursor-paged public creator monos (`GET /v1/mono/feed?writerId=…`).
class PublicProfileMonosNotifier
    extends StateNotifier<PublicProfileMonosState> {
  PublicProfileMonosNotifier(this._ref, this._familyUserId)
      : super(const PublicProfileMonosState());

  final Ref _ref;
  final String _familyUserId;

  static const int pageLimit = 10;
  static const double scrollPrefetchExtentPx = 600;

  bool _matches(String userId) => userId.trim() == _familyUserId.trim();

  CatalogDiscoveryLens? _catalogLens() =>
      CatalogDiscoveryLens.tryFromPreferences(
        _ref.read(userPreferencesNotifierProvider).prefs,
      );

  Future<void> loadInitial(String userId) async {
    if (!_matches(userId)) return;
    final id = userId.trim();
    if (id.isEmpty || id == '__none__') return;
    if (state.isInitialLoading) return;
    state = state.copyWith(
      isInitialLoading: true,
      error: null,
      loadMoreError: null,
      items: const [],
      hasMore: false,
      nextCursor: null,
    );
    try {
      final repo = _ref.read(remotePublicCreatorProfileRepositoryProvider);
      final page = await repo.fetchCreatorMonoPage(
        id,
        limit: pageLimit,
        catalogLens: _catalogLens(),
      );
      if (!_matches(userId)) return;
      state = state.copyWith(
        isInitialLoading: false,
        items: page.items.map(monoFeedItemFromMonoFeedSummary).toList(),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!_matches(userId)) return;
      state = state.copyWith(isInitialLoading: false, error: e);
    }
  }

  Future<void> refresh(String userId) async {
    if (!_matches(userId)) return;
    final id = userId.trim();
    if (id.isEmpty || id == '__none__') return;
    if (state.isRefreshing) return;
    state = state.copyWith(
      isRefreshing: true,
      error: null,
      loadMoreError: null,
    );
    try {
      final repo = _ref.read(remotePublicCreatorProfileRepositoryProvider);
      final page = await repo.fetchCreatorMonoPage(
        id,
        limit: pageLimit,
        catalogLens: _catalogLens(),
      );
      if (!_matches(userId)) return;
      state = state.copyWith(
        isRefreshing: false,
        items: page.items.map(monoFeedItemFromMonoFeedSummary).toList(),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!_matches(userId)) return;
      state = state.copyWith(
        isRefreshing: false,
        error: e,
      );
    }
  }

  Future<void> loadMore(String userId) async {
    if (!_matches(userId)) return;
    final id = userId.trim();
    if (id.isEmpty || id == '__none__') return;
    if (!state.canLoadMore) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.trim().isEmpty) return;
    if (state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    try {
      final repo = _ref.read(remotePublicCreatorProfileRepositoryProvider);
      final page = await repo.fetchCreatorMonoPage(
        id,
        cursor: cursor,
        limit: pageLimit,
        catalogLens: _catalogLens(),
      );
      if (!_matches(userId)) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: null,
        items: [
          ...state.items,
          ...page.items.map(monoFeedItemFromMonoFeedSummary)
        ],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!_matches(userId)) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  /// Called from Monos tab scroll when near the bottom.
  Future<void> maybePrefetchFromScroll(String userId) async {
    if (!_matches(userId)) return;
    if (!state.canLoadMore) return;
    await loadMore(userId);
  }
}

final publicProfileMonosProvider = StateNotifierProvider.autoDispose
    .family<PublicProfileMonosNotifier, PublicProfileMonosState, String>(
  (ref, userId) => PublicProfileMonosNotifier(ref, userId),
);
