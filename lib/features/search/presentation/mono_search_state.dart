import 'package:flutter/foundation.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';

const Object _unset = Object();

/// Filters + first-page / load-more flags for `GET /v1/search/monos` (M18B).
@immutable
class MonoSearchState {
  const MonoSearchState({
    this.query = '',
    this.selectedLevel,
    this.selectedCategory,
    this.sort = 'latest',
    this.items = const [],
    this.isLoadingFirstPage = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = false,
    this.nextCursor,
    this.totalCount,
    this.requestEpoch = 0,
    this.hasEverFetched = false,
  });

  /// Keyword sent as `q` (may contain spaces; repository trims).
  final String query;
  final String? selectedLevel;
  final String? selectedCategory;
  final String sort;
  final List<MonoSearchResult> items;

  final bool isLoadingFirstPage;
  final bool isLoadingMore;
  final Object? error;
  final bool hasMore;
  final String? nextCursor;
  final int? totalCount;
  final int requestEpoch;

  /// True after at least one **remote** search request (excludes idle / marketing state).
  final bool hasEverFetched;

  bool get canLoadMore =>
      hasMore &&
      !isLoadingMore &&
      !isLoadingFirstPage &&
      error == null &&
      (nextCursor != null && nextCursor!.isNotEmpty);

  MonoSearchState copyWith({
    String? query,
    Object? selectedLevel = _unset,
    Object? selectedCategory = _unset,
    String? sort,
    List<MonoSearchResult>? items,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    Object? error = _unset,
    bool? hasMore,
    Object? nextCursor = _unset,
    Object? totalCount = _unset,
    int? requestEpoch,
    bool? hasEverFetched,
  }) {
    return MonoSearchState(
      query: query ?? this.query,
      selectedLevel: selectedLevel == _unset
          ? this.selectedLevel
          : selectedLevel as String?,
      selectedCategory: selectedCategory == _unset
          ? this.selectedCategory
          : selectedCategory as String?,
      sort: sort ?? this.sort,
      items: items ?? this.items,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == _unset ? this.error : error,
      hasMore: hasMore ?? this.hasMore,
      nextCursor:
          nextCursor == _unset ? this.nextCursor : nextCursor as String?,
      totalCount: totalCount == _unset ? this.totalCount : totalCount as int?,
      requestEpoch: requestEpoch ?? this.requestEpoch,
      hasEverFetched: hasEverFetched ?? this.hasEverFetched,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonoSearchState &&
        other.query == query &&
        other.selectedLevel == selectedLevel &&
        other.selectedCategory == selectedCategory &&
        other.sort == sort &&
        listEquals(other.items, items) &&
        other.isLoadingFirstPage == isLoadingFirstPage &&
        other.isLoadingMore == isLoadingMore &&
        other.error == error &&
        other.hasMore == hasMore &&
        other.nextCursor == nextCursor &&
        other.totalCount == totalCount &&
        other.requestEpoch == requestEpoch &&
        other.hasEverFetched == hasEverFetched;
  }

  @override
  int get hashCode => Object.hash(
        query,
        selectedLevel,
        selectedCategory,
        sort,
        Object.hashAll(items),
        isLoadingFirstPage,
        isLoadingMore,
        error,
        hasMore,
        nextCursor,
        totalCount,
        requestEpoch,
        hasEverFetched,
      );
}
