import 'package:flutter/foundation.dart';

/// Immutable page envelope from a cursor-based API.
@immutable
class PageResult<T> {
  const PageResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
    this.totalCount,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final int? totalCount;

  factory PageResult.empty() => PageResult<T>(
        items: const [],
        nextCursor: null,
        hasMore: false,
        totalCount: null,
      );

  PageResult<U> map<U>(U Function(T item) convert) {
    return PageResult<U>(
      items: items.map(convert).toList(growable: false),
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: totalCount,
    );
  }

  /// Appends [next] after this page: concatenates [items], adopts [next]'s cursor and [hasMore].
  /// [totalCount]: keeps an existing authoritative [totalCount] from this page if [next] omits it.
  PageResult<T> append(PageResult<T> next) {
    return PageResult<T>(
      items: List<T>.unmodifiable(<T>[...items, ...next.items]),
      nextCursor: next.nextCursor,
      hasMore: next.hasMore,
      totalCount: next.totalCount ?? totalCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PageResult<T> &&
        listEquals(items, other.items) &&
        nextCursor == other.nextCursor &&
        hasMore == other.hasMore &&
        totalCount == other.totalCount;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(items),
        nextCursor,
        hasMore,
        totalCount,
      );
}
