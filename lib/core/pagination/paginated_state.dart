import 'package:flutter/foundation.dart';

const Object _unset = Object();

/// UI / notifier state for a single paged list surface.
@immutable
class PaginatedState<T> {
  const PaginatedState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
    this.requestEpoch = 0,
    this.totalCount,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;
  final int requestEpoch;

  /// Optional total item count from the backend (e.g. first page metadata).
  final int? totalCount;

  factory PaginatedState.initial() => const PaginatedState();

  bool get canLoadMore =>
      hasMore &&
      !isLoadingMore &&
      !isInitialLoading &&
      !isRefreshing &&
      error == null;

  bool get isBusy => isInitialLoading || isLoadingMore || isRefreshing;

  bool get isEmpty => items.isEmpty && !isInitialLoading;

  bool get hasError => error != null;

  PaginatedState<T> copyWith({
    List<T>? items,
    Object? nextCursor = _unset,
    bool? hasMore,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error = _unset,
    int? requestEpoch,
    Object? totalCount = _unset,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      nextCursor:
          nextCursor == _unset ? this.nextCursor : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error == _unset ? this.error : error,
      requestEpoch: requestEpoch ?? this.requestEpoch,
      totalCount: totalCount == _unset ? this.totalCount : totalCount as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaginatedState<T> &&
        listEquals(items, other.items) &&
        nextCursor == other.nextCursor &&
        hasMore == other.hasMore &&
        isInitialLoading == other.isInitialLoading &&
        isLoadingMore == other.isLoadingMore &&
        isRefreshing == other.isRefreshing &&
        error == other.error &&
        requestEpoch == other.requestEpoch &&
        totalCount == other.totalCount;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(items),
        nextCursor,
        hasMore,
        isInitialLoading,
        isLoadingMore,
        isRefreshing,
        error,
        requestEpoch,
        totalCount,
      );
}
