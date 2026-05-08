import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/mono/data/remote_mono_feed_repository.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

/// Remote Following feed over `GET /v1/mono/feed?following=true` (auth required).
class RemoteFollowingMonoFeedRepository implements MonoFeedRepository {
  RemoteFollowingMonoFeedRepository({
    required String apiBaseUrl,
    required MonoFeedAuthHeaderBuilder authHeaderBuilder,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder,
        _detailRepo = RemoteMonoFeedRepository(
          apiBaseUrl: apiBaseUrl,
          client: client,
          authHeaderBuilder: authHeaderBuilder,
        );

  final String _apiBaseUrl;
  final http.Client _client;
  final MonoFeedAuthHeaderBuilder _authHeaderBuilder;
  final RemoteMonoFeedRepository _detailRepo;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, String>> _authHeadersOrThrow() async {
    final h = await _authHeaderBuilder();
    if (h.isEmpty) {
      throw StateError('Sign in to see stories from people you follow.');
    }
    return h;
  }

  Map<String, Object?> _jsonObjectFromResponse(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
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

  Never _mapHttpError(http.Response r) {
    if (r.statusCode == 401) {
      throw StateError('Sign in to see stories from people you follow.');
    }
    final raw = r.body.trim();
    final msg =
        raw.isEmpty ? 'HTTP ${r.statusCode}' : 'HTTP ${r.statusCode}: $raw';
    throw StateError(msg);
  }

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    final qp = {
      ...request.toQueryParameters(),
      'following': 'true',
    };
    final uri = _u('/v1/mono/feed').replace(queryParameters: qp);
    if (kDebugMode) {
      debugPrint('RemoteFollowingMonoFeedRepository.fetchFeedPage: GET $uri');
    }
    final resp = await _client.get(
      uri,
      headers: {
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) _mapHttpError(resp);
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
    return PageResult<MonoFeedSummaryDto>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: null,
    );
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) {
    return _detailRepo.fetchMonoDetail(monoId);
  }
}
