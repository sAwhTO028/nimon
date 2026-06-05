import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/auth/authenticated_http.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/search/data/mono_search_remote.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';

typedef MonoSearchAuthHeaderBuilder = Future<Map<String, String>> Function();

/// Remote `GET /v1/search/monos` (M18A). Optional auth hydrates bookmark/reaction fields.
class RemoteMonoSearchRepository implements MonoSearchRemote {
  RemoteMonoSearchRepository({
    required String apiBaseUrl,
    http.Client? client,
    MonoSearchAuthHeaderBuilder? authHeaderBuilder,
    NimonSendWithAuth401Recovery? sendWithAuth401Recovery,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder,
        _sendWithAuth401 = sendWithAuth401Recovery;

  final String _apiBaseUrl;
  final http.Client _client;
  final MonoSearchAuthHeaderBuilder? _authHeaderBuilder;
  final NimonSendWithAuth401Recovery? _sendWithAuth401;

  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

  Future<Map<String, String>> _mergeAuth(Map<String, String> headers) async {
    final builder = _authHeaderBuilder;
    if (builder == null) return headers;
    final auth = await builder();
    if (auth.isEmpty) return headers;
    return {...auth, ...headers};
  }

  Future<http.Response> _nimonAuthSend(
    Uri uri,
    Future<Map<String, String>> Function() mergeHeaders,
    Future<http.Response> Function(Map<String, String> headers) send,
  ) =>
      nimonSendWithOptional401Recovery(
        _sendWithAuth401,
        requestUri: uri,
        mergeHeaders: mergeHeaders,
        send: send,
        requireAuthHeaderForRecovery: true,
      );

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

  void _throwIfNotOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    final msg = r.body.trim().isEmpty
        ? 'HTTP ${r.statusCode}'
        : 'HTTP ${r.statusCode}: ${r.body}';
    throw StateError(msg);
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

  bool _hasMoreFromJson(Map<String, Object?> m) {
    final v = m['hasMore'] ?? m['has_more'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true') return true;
      if (t == 'false') return false;
      if (t == '1') return true;
      if (t == '0') return false;
    }
    return false;
  }

  int? _totalCountFromJson(Map<String, Object?> m) {
    final v = m['totalCount'] ?? m['total_count'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? _nextCursorFromJson(Map<String, Object?> m) {
    return _optStr(
      m['nextCursor'] ?? m['next_cursor'] ?? m['next_page_cursor'],
    );
  }

  int _clampLimit(int limit) {
    return limit.clamp(
      PaginationDefaults.minPageLimit,
      PaginationDefaults.maxPageLimit,
    );
  }

  Map<String, String> _queryParams({
    String? q,
    String? level,
    String? category,
    required String sort,
    required int limit,
    String? cursor,
    CatalogDiscoveryLens? catalogLens,
    Map<String, String>? authHeaders,
  }) {
    final qp = <String, String>{
      'sort': sort,
      'limit': '${_clampLimit(limit)}',
    };
    final qq = q?.trim();
    if (qq != null && qq.isNotEmpty) qp['q'] = qq;
    final lv = level?.trim();
    if (lv != null && lv.isNotEmpty) qp['level'] = lv;
    final cat = category?.trim();
    if (cat != null && cat.isNotEmpty) qp['category'] = cat;
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) qp['cursor'] = c;
    CatalogDiscoveryLens.mergeIntoQueryIfAuthenticated(
      qp,
      catalogLens,
      authHeaders ?? const {},
    );
    return qp;
  }

  PaginatedPage<MonoSearchResult> _parseEnvelope(Map<String, Object?> m) {
    final rawItems = (m['items'] as List?) ?? const [];
    final items = <MonoSearchResult>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(MonoSearchResult.fromBackendJson(it));
    }
    return PaginatedPage<MonoSearchResult>(
      items: items,
      nextCursor: _nextCursorFromJson(m),
      hasMore: _hasMoreFromJson(m),
      totalCount: _totalCountFromJson(m),
    );
  }

  /// Cursor-paged catalog search over published monos.
  @override
  Future<PaginatedPage<MonoSearchResult>> searchMonos({
    String? q,
    String? level,
    String? category,
    String sort = 'latest',
    int limit = PaginationDefaults.defaultPageLimit,
    String? cursor,
    CatalogDiscoveryLens? catalogLens,
  }) async {
    try {
      final lim = _clampLimit(limit);
      final headers = await _mergeAuth(const {'Accept': 'application/json'});
      final uri = _u('/v1/search/monos').replace(
        queryParameters: _queryParams(
          q: q,
          level: level,
          category: category,
          sort: sort,
          limit: lim,
          cursor: cursor,
          catalogLens: catalogLens,
          authHeaders: headers,
        ),
      );
      if (kDebugMode) {
        debugPrint('RemoteMonoSearchRepository.searchMonos: GET $uri');
      }
      final resp = await _nimonAuthSend(
        uri,
        () async => headers,
        (h) => _client.get(uri, headers: h),
      );
      _throwIfNotOk(resp);
      final m = _jsonObjectFromResponse(resp);
      return _parseEnvelope(m);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RemoteMonoSearchRepository.searchMonos error: $e\n$st');
      }
      if (_strict) rethrow;
      return PaginatedPage<MonoSearchResult>.empty();
    }
  }
}
