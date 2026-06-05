import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/search/data/mono_search_remote.dart';
import 'package:nimon/features/search/presentation/mono_search_state.dart';

/// Search list + filters for published mono search (M18B/M18C).
typedef CatalogDiscoveryLensReader = CatalogDiscoveryLens? Function();

class MonoSearchNotifier extends StateNotifier<MonoSearchState> {
  MonoSearchNotifier(
    this._repo, {
    int pageLimit = PaginationDefaults.defaultPageLimit,
    Duration? debounce,
    CatalogDiscoveryLensReader? catalogLens,
  })  : _pageLimit = pageLimit,
        _debounce = debounce ??
            const Duration(milliseconds: PaginationDefaults.searchDebounceMs),
        _catalogLens = catalogLens ?? (() => null),
        super(const MonoSearchState());

  final MonoSearchRemote _repo;
  final int _pageLimit;
  final Duration _debounce;
  final CatalogDiscoveryLensReader _catalogLens;

  Timer? _queryDebounce;

  int get pageLimit => _pageLimit;

  /// True when query/level/category warrant a remote search (M18B/M23A-6D-1).
  static bool shouldFetchRemote(MonoSearchState s) {
    if (s.query.trim().isNotEmpty) return true;
    final lv = s.selectedLevel?.trim();
    if (lv != null && lv.isNotEmpty) return true;
    final cat = s.selectedCategory?.trim();
    if (cat != null && cat.isNotEmpty) return true;
    return false;
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    super.dispose();
  }

  /// Updates [MonoSearchState.query] and reloads the first page after [debounce].
  void setQuery(String text) {
    state = state.copyWith(query: text);
    _queryDebounce?.cancel();
    _queryDebounce = Timer(_debounce, () {
      unawaited(_loadFirstPageInternal());
    });
  }

  /// Applies [query] immediately and fetches the first page (no debounce).
  Future<void> setQueryAndReload(String text) {
    _queryDebounce?.cancel();
    state = state.copyWith(query: text);
    return _loadFirstPageInternal();
  }

  Future<void> setLevel(String? level) {
    _queryDebounce?.cancel();
    state = state.copyWith(selectedLevel: level);
    return _loadFirstPageInternal();
  }

  Future<void> setCategory(String? category) {
    _queryDebounce?.cancel();
    state = state.copyWith(selectedCategory: category);
    return _loadFirstPageInternal();
  }

  Future<void> setSort(String sort) {
    _queryDebounce?.cancel();
    state = state.copyWith(sort: sort);
    return _loadFirstPageInternal();
  }

  Future<void> refresh() => _loadFirstPageInternal();

  Future<void> clearFilters() {
    _queryDebounce?.cancel();
    state = state.copyWith(
      query: '',
      selectedLevel: null,
      selectedCategory: null,
      sort: 'latest',
    );
    return _loadFirstPageInternal();
  }

  Future<void> _loadFirstPageInternal() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isLoadingFirstPage: true,
      isLoadingMore: false,
      items: const [],
      nextCursor: null,
      hasMore: false,
      totalCount: null,
      error: null,
    );

    if (!shouldFetchRemote(state)) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        isLoadingFirstPage: false,
        hasEverFetched: false,
      );
      return;
    }

    if (state.requestEpoch != myEpoch) return;
    state = state.copyWith(hasEverFetched: true);

    try {
      final q = state.query.trim();
      final result = await _repo.searchMonos(
        q: q.isEmpty ? null : q,
        level: state.selectedLevel,
        category: state.selectedCategory,
        sort: state.sort,
        limit: _pageLimit,
        cursor: null,
        catalogLens: _catalogLens(),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isLoadingFirstPage: false,
        error: null,
        totalCount: result.totalCount,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        isLoadingFirstPage: false,
        error: e,
      );
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isLoadingFirstPage: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (kDebugMode) {
      debugPrint(
        '[MonoSearch] loadMore canLoadMore=${state.canLoadMore} '
        'hasMore=${state.hasMore} isLoadingMore=${state.isLoadingMore}',
      );
    }
    if (!state.canLoadMore) return;
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final q = state.query.trim();
      final result = await _repo.searchMonos(
        q: q.isEmpty ? null : q,
        level: state.selectedLevel,
        category: state.selectedCategory,
        sort: state.sort,
        limit: _pageLimit,
        cursor: cursor,
        catalogLens: _catalogLens(),
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
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(error: e);
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
