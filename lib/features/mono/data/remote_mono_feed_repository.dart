import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

typedef MonoFeedAuthHeaderBuilder = Future<Map<String, String>> Function();

/// Remote catalog over `GET /v1/mono/feed` and `GET /v1/mono/:monoId` (public reads).
///
/// Optional [authHeaderBuilder]: merged into headers when non-null; catalog does **not**
/// require Authorization.
class RemoteMonoFeedRepository implements MonoFeedRepository {
  RemoteMonoFeedRepository({
    required String apiBaseUrl,
    http.Client? client,
    MonoFeedAuthHeaderBuilder? authHeaderBuilder,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder;

  final String _apiBaseUrl;
  final http.Client _client;
  final MonoFeedAuthHeaderBuilder? _authHeaderBuilder;

  Future<Map<String, String>> _mergeOptionalAuth(
      Map<String, String> headers) async {
    final builder = _authHeaderBuilder;
    if (builder == null) return headers;
    final auth = await builder();
    if (auth.isEmpty) return headers;
    return {...auth, ...headers};
  }

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Map<String, Object?> _jsonObjectFromResponse(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
  }

  String _formatHttpError(http.Response r) {
    final code = r.statusCode;
    final raw = r.body.trim();
    if (raw.isEmpty) return 'HTTP $code';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final m = decoded['message'];
        if (m != null && '$m'.trim().isNotEmpty) {
          return 'HTTP $code: $m';
        }
        final codeStr = decoded['code'];
        if (codeStr != null && '$codeStr'.trim().isNotEmpty) {
          return 'HTTP $code ($codeStr)';
        }
      }
    } catch (_) {}
    return raw.length > 280 ? '${raw.substring(0, 280)}…' : 'HTTP $code: $raw';
  }

  void _throwIfNotOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    throw StateError(_formatHttpError(r));
  }

  static String? _optStr(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  /// Backend accepts max 30 per page for mono feed (M3a).
  static int _clampMonoLimit(int limit) {
    return limit.clamp(
      PaginationDefaults.minPageLimit,
      30,
    );
  }

  PageRequest _effectiveRequest(
    PageRequest request, {
    String? level,
    String? category,
  }) {
    final lim = _clampMonoLimit(request.limit);
    return PageRequest(
      cursor: request.cursor,
      limit: lim,
      sort: 'recent',
      query: request.query,
      level: level ?? request.level,
      category: category ?? request.category,
      ownerId: request.ownerId,
      status: request.status,
      publishState: request.publishState,
      accessType: request.accessType,
      updatedAfter: request.updatedAfter,
    );
  }

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    final effective =
        _effectiveRequest(request, level: level, category: category);
    final qp = effective.toQueryParameters();
    final uri = _u('/v1/mono/feed').replace(queryParameters: qp);
    if (kDebugMode) {
      debugPrint('RemoteMonoFeedRepository.fetchFeedPage: GET $uri');
    }
    final headers = await _mergeOptionalAuth({
      'Accept': 'application/json',
    });
    final resp = await _client.get(uri, headers: headers);
    if (kDebugMode) {
      final authPresent = headers.containsKey('Authorization');
      debugPrint(
        'RemoteMonoFeedRepository.fetchFeedPage: status=${resp.statusCode} '
        'auth=$authPresent',
      );
    }
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final rawItems = (m['items'] as List?) ?? const [];
    final items = <MonoFeedSummaryDto>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(MonoFeedSummaryDto.fromJson(it));
    }
    final nextCursor = _optStr(m['nextCursor']);
    final hasMore = m['hasMore'] is bool ? m['hasMore'] as bool : false;
    if (kDebugMode) {
      debugPrint(
        'RemoteMonoFeedRepository.fetchFeedPage: items=${items.length} '
        'hasMore=$hasMore nextCursor=${nextCursor != null}',
      );
    }
    return PageResult<MonoFeedSummaryDto>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: null,
    );
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) async {
    final rid = monoId.trim();
    if (rid.isEmpty) {
      throw ArgumentError('monoId is empty');
    }
    final resp = await _client.get(
      _u('/v1/mono/$rid'),
      headers: await _mergeOptionalAuth({
        'Accept': 'application/json',
      }),
    );
    if (resp.statusCode == 404) {
      throw PublishedMonoHiddenWhileEditingException();
    }
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    int readInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    bool readBool(Object? v) {
      if (v == null) return false;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    return PublishedMonoDetailDto(
      id: _optStr(m['id']) ?? '',
      ownerId: _optStr(m['ownerId']) ?? '',
      sourceDraftId: readPublishedMonoSourceDraftIdFromJson(m),
      title: _optStr(m['title']) ?? '',
      category: _optStr(m['category']) ?? '',
      level: _optStr(m['level']) ?? '',
      description: _optStr(m['description']) ?? '',
      publishKind: _optStr(m['publishKind']),
      displayPublishKind: _optStr(m['displayPublishKind']) ?? 'unknown',
      coverImageUrl: _optStr(m['coverImageUrl']),
      targetDurationLabel: _optStr(m['targetDurationLabel']),
      createdAt: _optStr(m['createdAt']) ?? '',
      updatedAt: _optStr(m['updatedAt']) ?? '',
      contentSummary: m['contentSummary'],
      content: m['content'],
      likesCount: readInt(m['likesCount']),
      isBookmarkedByMe: readBool(m['isBookmarkedByMe']),
      myReaction: _optStr(m['myReaction']),
      shareUrl: _optStr(m['shareUrl']),
      writerDisplayName: _optStr(m['writerDisplayName']),
      writerHandle: _optStr(m['writerHandle']),
      writerAvatarUrl: _optStr(m['writerAvatarUrl']),
    );
  }
}
