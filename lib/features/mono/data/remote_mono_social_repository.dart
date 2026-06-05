import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/validation/quota_exceeded_from_json.dart';
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/auth/authenticated_http.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';

typedef MonoSocialAuthHeaderBuilder = Future<Map<String, String>> Function();

class RemoteMonoSocialRepository {
  RemoteMonoSocialRepository({
    required String apiBaseUrl,
    required MonoSocialAuthHeaderBuilder authHeaderBuilder,
    http.Client? client,
    NimonSendWithAuth401Recovery? sendWithAuth401Recovery,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _authHeaderBuilder = authHeaderBuilder,
        _client = client ?? http.Client(),
        _sendWithAuth401 = sendWithAuth401Recovery;

  final String _apiBaseUrl;
  final MonoSocialAuthHeaderBuilder _authHeaderBuilder;
  final http.Client _client;
  final NimonSendWithAuth401Recovery? _sendWithAuth401;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, String>> _authHeadersOrThrow() async {
    final h = await _authHeaderBuilder();
    if (h.isEmpty || (h['Authorization'] ?? '').trim().isEmpty) {
      throw StateError('Sign in required.');
    }
    return h;
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
      );

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

  static int _int(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _bool(Object? v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  void _throwIfNotOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 401) notifyIfStrictUnauthorized401(r);
    final quota = tryParseQuotaExceededFromHttpBody(r.body);
    if (quota != null) throw quota;
    if (r.statusCode == 401) {
      throw StateError('Sign in required.');
    }
    if (r.statusCode == 404) {
      throw StateError('This story is not available right now.');
    }
    final msg = r.body.trim().isEmpty
        ? 'HTTP ${r.statusCode}'
        : 'HTTP ${r.statusCode}: ${r.body}';
    throw StateError(msg);
  }

  /// Same envelope merge strategy as the published-monos list client (M17I).
  Map<String, Object?> _normalizedBookmarksListJson(Map<String, Object?> root) {
    var m = Map<String, Object?>.from(root);

    void mergeSecondaryObject(Object? section) {
      if (section is! Map) return;
      final sm = Map<String, Object?>.from(
        section.map((k, v) => MapEntry(k.toString(), v)),
      );
      for (final e in sm.entries) {
        final k = e.key;
        if (!m.containsKey(k) || m[k] == null) {
          m[k] = e.value;
        }
      }
    }

    var topItems = m['items'];
    if (topItems is! List) {
      final data = m['data'];
      if (data is List) {
        m = {...m, 'items': data};
      } else if (data is Map) {
        final dm = Map<String, Object?>.from(
          data.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (dm['items'] is List) {
          m = {...m, ...dm};
        }
      }
    }

    mergeSecondaryObject(m['pagination']);
    final dataSibling = m['data'];
    if (dataSibling is Map) {
      mergeSecondaryObject(dataSibling);
    }
    mergeSecondaryObject(m['meta']);

    return m;
  }

  static bool _hasMoreFromBookmarksJson(Map<String, Object?> m) {
    final v = m['hasMore'] ?? m['has_more'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true' || t == '1') return true;
      if (t == 'false' || t == '0') return false;
    }
    return false;
  }

  static String? _nextCursorFromBookmarksJson(Map<String, Object?> m) {
    return _optStr(
      m['nextCursor'] ?? m['next_cursor'] ?? m['next_page_cursor'],
    );
  }

  static int? _totalCountFromBookmarksJson(Map<String, Object?> m) {
    final v = m['totalCount'] ?? m['total_count'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// `GET /v1/me/bookmarks?cursor=&limit=` (JWT required).
  Future<PageResult<MonoFeedItem>> fetchBookmarkedPage(
      PageRequest request) async {
    final qp = <String, String>{
      if (request.cursor != null && request.cursor!.trim().isNotEmpty)
        'cursor': request.cursor!.trim(),
      'limit': request.limit.toString(),
    };
    final uri = _u('/v1/me/bookmarks').replace(queryParameters: qp);
    if (kDebugMode) {
      debugPrint(
        '[SavedTab] before GET limit=${request.limit} '
        'cursor=${request.cursor == null || request.cursor!.trim().isEmpty ? "null" : "set"} '
        'uri=$uri',
      );
    }
    final resp = await _nimonAuthSend(
      uri,
      () async => <String, String>{
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
      (h) => _client.get(uri, headers: h),
    );
    _throwIfNotOk(resp);
    final root = _jsonObjectFromResponse(resp);
    if (kDebugMode) {
      final rk = root.keys.map((k) => k.toString()).toList()..sort();
      debugPrint('[SavedTab] raw keys=$rk');
    }
    final m = _normalizedBookmarksListJson(root);
    final rawItems = (m['items'] as List?) ?? const [];
    final items = <MonoFeedItem>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      final id = _optStr(it['monoId']) ?? _optStr(it['publishedMonoId']) ?? '';
      if (id.trim().isEmpty) continue;
      final title = _optStr(it['title']);
      final desc = (_optStr(it['description']) ?? '').trim();
      final whRaw = (_optStr(it['writerHandle']) ?? '').trim();
      final av = (_optStr(it['writerAvatarUrl']) ?? '').trim();
      final catRaw = (_optStr(it['category']) ?? '').trim();
      final tdRaw = (_optStr(it['targetDurationLabel']) ?? '').trim();
      items.add(
        MonoFeedItem(
          id: id,
          writerName: (_optStr(it['writerDisplayName']) ?? '').trim().isNotEmpty
              ? (_optStr(it['writerDisplayName']) ?? '').trim()
              : ((_optStr(it['writerHandle']) ?? '').trim().isNotEmpty
                  ? (_optStr(it['writerHandle']) ?? '').trim()
                  : 'Writer'),
          writerHandle: whRaw.isNotEmpty
              ? (whRaw.startsWith('@') ? whRaw : '@$whRaw')
              : '@reader',
          writerAvatarUrl: av.isNotEmpty ? av : null,
          level: (_optStr(it['level']) ?? '').trim().isNotEmpty
              ? (_optStr(it['level']) ?? '').trim()
              : '—',
          contentType: MonoContentType.article,
          title: title?.trim().isEmpty == true ? null : title?.trim(),
          bodyText: desc,
          storyDescription: desc,
          coverImageUrl: _optStr(it['coverUrl']),
          needsRemoteDetailHydration: true,
          likesCount: _int(it['likesCount']),
          isBookmarkedByMe: _bool(it['isBookmarkedByMe']),
          myReaction: _optStr(it['myReaction']),
          shareUrl: _optStr(it['shareUrl']),
          catalogCategory: catRaw.isNotEmpty ? catRaw : null,
          readDurationLabel: tdRaw.isNotEmpty ? tdRaw : null,
          contentLocale: _optStr(it['contentLocale']),
          learningLanguage: _optStr(it['learningLanguage']),
        ),
      );
    }
    final nextCursor = _nextCursorFromBookmarksJson(m);
    final hasMore = _hasMoreFromBookmarksJson(m);
    final totalCount = _totalCountFromBookmarksJson(m);
    if (kDebugMode) {
      debugPrint(
        '[SavedTab] parsed items=${items.length} hasMore=$hasMore '
        'nextCursor=${nextCursor == null ? "null" : (nextCursor.isEmpty ? "empty" : "set")} '
        'totalCount=$totalCount',
      );
    }
    return PageResult<MonoFeedItem>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: totalCount,
    );
  }

  Future<bool> bookmarkMono(String monoId) async {
    final rid = monoId.trim();
    if (rid.isEmpty) throw ArgumentError('monoId is empty');
    final uri = _u('/v1/mono/$rid/bookmark');
    if (kDebugMode) {
      debugPrint('RemoteMonoSocialRepository.bookmarkMono: POST $uri');
    }
    final resp = await _nimonAuthSend(
      uri,
      () async => <String, String>{
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
      (h) => _client.post(uri, headers: h),
    );
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    return (m['isBookmarkedByMe'] is bool)
        ? (m['isBookmarkedByMe'] as bool)
        : true;
  }

  Future<bool> unbookmarkMono(String monoId) async {
    final rid = monoId.trim();
    if (rid.isEmpty) throw ArgumentError('monoId is empty');
    final uri = _u('/v1/mono/$rid/bookmark');
    if (kDebugMode) {
      debugPrint('RemoteMonoSocialRepository.unbookmarkMono: DELETE $uri');
    }
    final resp = await _nimonAuthSend(
      uri,
      () async => <String, String>{
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
      (h) => _client.delete(uri, headers: h),
    );
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    return (m['isBookmarkedByMe'] is bool)
        ? (m['isBookmarkedByMe'] as bool)
        : false;
  }

  Future<int> reactMono(String monoId) async {
    final rid = monoId.trim();
    if (rid.isEmpty) throw ArgumentError('monoId is empty');
    final uri = _u('/v1/mono/$rid/react');
    if (kDebugMode) {
      debugPrint('RemoteMonoSocialRepository.reactMono: POST $uri');
    }
    final resp = await _nimonAuthSend(
      uri,
      () async => <String, String>{
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
      (h) => _client.post(uri, headers: h),
    );
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final v = m['likesCount'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<int> unreactMono(String monoId) async {
    final rid = monoId.trim();
    if (rid.isEmpty) throw ArgumentError('monoId is empty');
    final uri = _u('/v1/mono/$rid/react');
    if (kDebugMode) {
      debugPrint('RemoteMonoSocialRepository.unreactMono: DELETE $uri');
    }
    final resp = await _nimonAuthSend(
      uri,
      () async => <String, String>{
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
      (h) => _client.delete(uri, headers: h),
    );
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final v = m['likesCount'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
