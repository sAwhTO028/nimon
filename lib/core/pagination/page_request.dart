import 'package:flutter/foundation.dart';

import 'pagination_defaults.dart';

/// Sentinel for [PageRequest.copyWith] to distinguish "omit" from "set null".
@immutable
class _Unset {
  const _Unset();
}

const Object _unset = _Unset();

/// Immutable cursor page request for repository / HTTP query mapping.
@immutable
class PageRequest {
  PageRequest({
    this.cursor,
    int? limit,
    String? sort,
    this.query,
    this.level,
    this.category,
    this.ownerId,
    this.status,
    this.publishState,
    this.accessType,
    this.updatedAfter,
  })  : limit = (limit ?? PaginationDefaults.defaultPageLimit).clamp(
          PaginationDefaults.minPageLimit,
          PaginationDefaults.maxPageLimit,
        ),
        sort = sort ?? 'latest';

  final String? cursor;
  final int limit;
  final String sort;
  final String? query;
  final String? level;
  final String? category;
  final String? ownerId;
  final String? status;

  /// Story draft list filter (e.g. `draft`, `reading_only_published`) — see GET /v1/story-drafts.
  final String? publishState;
  final String? accessType;
  final DateTime? updatedAfter;

  PageRequest copyWith({
    Object? cursor = _unset,
    int? limit,
    Object? sort = _unset,
    Object? query = _unset,
    Object? level = _unset,
    Object? category = _unset,
    Object? ownerId = _unset,
    Object? status = _unset,
    Object? publishState = _unset,
    Object? accessType = _unset,
    Object? updatedAfter = _unset,
  }) {
    return PageRequest(
      cursor: cursor == _unset ? this.cursor : cursor as String?,
      limit: limit ?? this.limit,
      sort: sort == _unset ? this.sort : sort as String,
      query: query == _unset ? this.query : query as String?,
      level: level == _unset ? this.level : level as String?,
      category: category == _unset ? this.category : category as String?,
      ownerId: ownerId == _unset ? this.ownerId : ownerId as String?,
      status: status == _unset ? this.status : status as String?,
      publishState:
          publishState == _unset ? this.publishState : publishState as String?,
      accessType:
          accessType == _unset ? this.accessType : accessType as String?,
      updatedAfter: updatedAfter == _unset
          ? this.updatedAfter
          : updatedAfter as DateTime?,
    );
  }

  /// Query string values: omits null/empty strings; [updatedAfter] as UTC ISO-8601.
  /// Always includes [limit] and [sort].
  Map<String, String> toQueryParameters() {
    final out = <String, String>{
      'limit': limit.toString(),
      'sort': sort,
    };
    void putIfNonEmpty(String key, String? value) {
      if (value == null || value.isEmpty) return;
      out[key] = value;
    }

    putIfNonEmpty('cursor', cursor);
    putIfNonEmpty('query', query);
    putIfNonEmpty('level', level);
    putIfNonEmpty('category', category);
    putIfNonEmpty('ownerId', ownerId);
    putIfNonEmpty('status', status);
    putIfNonEmpty('publishState', publishState);
    putIfNonEmpty('accessType', accessType);
    if (updatedAfter != null) {
      out['updatedAfter'] = updatedAfter!.toUtc().toIso8601String();
    }
    return Map<String, String>.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) {
    return other is PageRequest &&
        cursor == other.cursor &&
        limit == other.limit &&
        sort == other.sort &&
        query == other.query &&
        level == other.level &&
        category == other.category &&
        ownerId == other.ownerId &&
        status == other.status &&
        publishState == other.publishState &&
        accessType == other.accessType &&
        updatedAfter == other.updatedAfter;
  }

  @override
  int get hashCode => Object.hash(
        cursor,
        limit,
        sort,
        query,
        level,
        category,
        ownerId,
        status,
        publishState,
        accessType,
        updatedAfter,
      );
}
