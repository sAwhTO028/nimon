import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/quota_exceeded_from_json.dart';
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/auth/authenticated_http.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

typedef PublishedMonoAuthHeaderBuilder = Future<Map<String, String>> Function();

class RemotePublishedMonoRepository {
  RemotePublishedMonoRepository({
    required String apiBaseUrl,
    http.Client? client,
    PublishedMonoAuthHeaderBuilder? authHeaderBuilder,
    NimonSendWithAuth401Recovery? sendWithAuth401Recovery,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder,
        _sendWithAuth401 = sendWithAuth401Recovery;

  final String _apiBaseUrl;
  final http.Client _client;
  final PublishedMonoAuthHeaderBuilder? _authHeaderBuilder;
  final NimonSendWithAuth401Recovery? _sendWithAuth401;

  Future<Map<String, String>> _mergeAuth(Map<String, String> headers) async {
    final builder = _authHeaderBuilder;
    if (builder == null) return headers;
    final auth = await builder();
    return {...auth, ...headers};
  }

  Future<http.Response> _nimonAuthSend(
    Uri uri,
    Future<Map<String, String>> Function() mergeHeaders,
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool requireAuthHeaderForRecovery = true,
  }) =>
      nimonSendWithOptional401Recovery(
        _sendWithAuth401,
        requestUri: uri,
        mergeHeaders: mergeHeaders,
        send: send,
        requireAuthHeaderForRecovery: requireAuthHeaderForRecovery,
      );

  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

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
    if (r.statusCode == 401) notifyIfStrictUnauthorized401(r);
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
    return v.toString().trim().isEmpty ? null : v.toString().trim();
  }

  Uri _publishedMonosListUri(Map<String, String> query) {
    final base = Uri.parse('$_apiBaseUrl/v1/published-monos');
    return base.replace(queryParameters: query);
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

  /// Some gateways wrap the list in `data` (object or array), or put paging in
  /// `pagination` / `meta`. Merge those into a single map before reading `items`
  /// and cursors (M17C-4).
  Map<String, Object?> _normalizedPublishedMonosListJson(
    Map<String, Object?> root,
  ) {
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

  /// M17C-4 / M17C-5: log raw envelope + long body prefix before merge/parse (debug only).
  void _debugLogPublishedMonosFetchPageRaw(
    http.Response resp,
    Map<String, Object?> root,
  ) {
    if (!kDebugMode) return;
    final keys = root.keys.map((k) => k.toString()).toList()..sort();
    final rHm = root['hasMore'] ?? root['has_more'];
    final rNc = root['nextCursor'] ?? root['next_cursor'];
    final rTc = root['totalCount'] ?? root['total_count'];
    debugPrint(
      'RemotePublishedMonoRepository.fetchPage [RAW JSON envelope] '
      'status=${resp.statusCode} topLevelKeys=$keys '
      'root.hasMore|has_more=$rHm root.nextCursor|next_cursor=$rNc '
      'root.totalCount|total_count=$rTc',
    );
    final data = root['data'];
    if (data is Map) {
      final dk = data.keys.map((k) => k.toString()).toList()..sort();
      debugPrint(
        'RemotePublishedMonoRepository.fetchPage [M17C-5 RAW data] keys=$dk',
      );
    }
    final meta = root['meta'];
    if (meta is Map) {
      final mk = meta.keys.map((k) => k.toString()).toList()..sort();
      final mHm = meta['hasMore'] ?? meta['has_more'];
      final mNc = meta['nextCursor'] ?? meta['next_cursor'];
      final mTc = meta['totalCount'] ?? meta['total_count'];
      debugPrint(
        'RemotePublishedMonoRepository.fetchPage [M17C-5 RAW meta] keys=$mk '
        'hasMore|has_more=$mHm nextCursor|next_cursor=$mNc totalCount|total_count=$mTc',
      );
    }
    final body = resp.body.trim();
    if (body.isEmpty) return;
    const cap = 8192;
    final prefix = body.length <= cap ? body : '${body.substring(0, cap)}…';
    final suffix = body.length > cap ? ' (${body.length} chars total)' : '';
    debugPrint(
      'RemotePublishedMonoRepository.fetchPage [M17C-5 RAW body prefix]$suffix $prefix',
    );
  }

  PublishedMonoListItemDto _listItemFromMap(Map<String, Object?> it) {
    return publishedMonoListItemDtoFromBackendJson(it);
  }

  String _friendlyBackendUserMessage(http.Response r,
      {required String fallback}) {
    final body = r.body.trim();
    if (body.isEmpty) return fallback;
    List<String>? messageParts;
    String? single;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message'];
        if (msg is String) {
          single = msg.trim().isEmpty ? null : msg.trim();
        } else if (msg is List) {
          messageParts = msg
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false);
        }
      }
    } catch (_) {}

    final joined = single ??
        (messageParts != null && messageParts.isNotEmpty
            ? messageParts.join(' ')
            : null);

    final codeLike = joined?.trim();
    if (codeLike == null || codeLike.isEmpty) {
      return fallback;
    }

    switch (codeLike) {
      case 'published_mono_not_found':
      case 'published_mono_missing':
        return 'That published story could not be found.';
      case 'published_mono_not_trashed':
        return 'This story is not in Trash.';
      case 'published_mono_must_be_trashed_first':
        return 'Move this story to Trash first.';
      case 'missing_delete_confirm':
        return 'Something went wrong. Please try again.';
      default:
        if (codeLike.length > 200) {
          return fallback;
        }
        return codeLike;
    }
  }

  Never _throwFriendlyMutationFailure(http.Response r,
      {required String fallback}) {
    if (r.statusCode == 401) notifyIfStrictUnauthorized401(r);
    throw StateError(_friendlyBackendUserMessage(r, fallback: fallback));
  }

  PublishedMonoTrashMutationResult _trashMutationFromResponse(http.Response r) {
    final m = _jsonObjectFromResponse(r);
    return PublishedMonoTrashMutationResult(
      id: _optStr(m['id']) ?? '',
      trashedAt: _optStr(m['trashedAt']),
    );
  }

  PublishedMonoListResponseDto _listResponseDtoFromMap(Map<String, Object?> m) {
    final merged = _normalizedPublishedMonosListJson(m);
    final rawItems = (merged['items'] as List?) ?? const [];
    final items = <PublishedMonoListItemDto>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(_listItemFromMap(it));
    }
    return PublishedMonoListResponseDto(
      items: items,
      nextCursor: _nextCursorFromJson(merged),
      hasMore: _hasMoreFromJson(merged),
      totalCount: _totalCountFromJson(merged),
    );
  }

  PageResult<PublishedMonoListItemDto> _pageResultFromListDto(
    PublishedMonoListResponseDto dto,
  ) {
    return PageResult<PublishedMonoListItemDto>(
      items: dto.items,
      nextCursor: dto.nextCursor,
      hasMore: dto.hasMore,
      totalCount: dto.totalCount,
    );
  }

  Future<PublishedMonoListResponseDto> list({int limit = 20}) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.list: GET /v1/published-monos?limit=$limit',
        );
      }
      final uri = _publishedMonosListUri({'limit': '$limit'});
      final resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth({}),
        (h) => _client.get(uri, headers: h),
      );
      _throwIfNotOk(resp);
      final m = _jsonObjectFromResponse(resp);
      final dto = _listResponseDtoFromMap(m);
      if (kDebugMode) {
        final rawItems = (m['items'] as List?) ?? const [];
        debugPrint(
          'RemotePublishedMonoRepository.list: JSON items=${rawItems.length} parsedDtos=${dto.items.length}',
        );
      }
      return dto;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RemotePublishedMonoRepository.list error: $e\n$st');
      }
      if (_strict) rethrow;
      return const PublishedMonoListResponseDto(items: []);
    }
  }

  /// Cursor-paged fetch for Profile Published; maps [PageRequest] to query params.
  ///
  /// Legacy responses with only `{ "items": [...] }` become a single page with
  /// `hasMore: false`, `nextCursor: null`, `totalCount: null`.
  Future<PageResult<PublishedMonoListItemDto>> fetchPage(
    PageRequest request,
  ) async {
    try {
      final qp = request.toQueryParameters();
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.fetchPage: GET /v1/published-monos $qp',
        );
      }
      final uri = _publishedMonosListUri(qp);
      final resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth({}),
        (h) => _client.get(uri, headers: h),
      );
      _throwIfNotOk(resp);
      final m = _jsonObjectFromResponse(resp);
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.fetchPage: raw keys=${m.keys}',
        );
      }
      _debugLogPublishedMonosFetchPageRaw(resp, m);
      final dto = _listResponseDtoFromMap(m);
      if (kDebugMode) {
        final merged = _normalizedPublishedMonosListJson(m);
        final rawItems = (merged['items'] as List?) ?? const [];
        final nc = dto.nextCursor;
        final ncLabel = nc == null ? 'null' : (nc.isEmpty ? 'empty' : nc);
        debugPrint(
          'RemotePublishedMonoRepository.fetchPage [M17C-5 PARSED] '
          'hasMore=${dto.hasMore} nextCursor=$ncLabel totalCount=${dto.totalCount}',
        );
        debugPrint(
          'RemotePublishedMonoRepository.fetchPage: JSON items=${rawItems.length} '
          'parsedDtos=${dto.items.length} hasMore=${dto.hasMore} '
          'nextCursor=${nc == null ? 'null' : (nc.isEmpty ? 'empty' : 'set')} totalCount=${dto.totalCount}',
        );
      }
      return _pageResultFromListDto(dto);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RemotePublishedMonoRepository.fetchPage error: $e\n$st');
      }
      if (_strict) rethrow;
      return PageResult<PublishedMonoListItemDto>.empty();
    }
  }

  /// Owner trash list — `GET /v1/published-monos?trashed=true`.
  Future<PageResult<PublishedMonoListItemDto>> fetchTrashedPage(
    PageRequest request,
  ) async {
    try {
      final qp = Map<String, String>.from(request.toQueryParameters());
      qp['trashed'] = 'true';
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.fetchTrashedPage: '
          'GET /v1/published-monos $qp',
        );
      }
      final uri = _publishedMonosListUri(qp);
      final resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth({}),
        (h) => _client.get(uri, headers: h),
      );
      _throwIfNotOk(resp);
      final m = _jsonObjectFromResponse(resp);
      final dto = _listResponseDtoFromMap(m);
      return _pageResultFromListDto(dto);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.fetchTrashedPage error: $e\n$st',
        );
      }
      if (_strict) rethrow;
      return PageResult<PublishedMonoListItemDto>.empty();
    }
  }

  Future<PublishedMonoTrashMutationResult> trashPublishedMono(String id) async {
    final rid = id.trim();
    if (rid.isEmpty) {
      throw ArgumentError('publishedMono id is empty');
    }
    final uri = _u('/v1/published-monos/$rid/trash');
    http.Response resp;
    try {
      resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth(<String, String>{
          'Content-Type': 'application/json',
        }),
        (h) => _client.post(uri, headers: h),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RemotePublishedMonoRepository.trashPublishedMono error: '
            '$e\n$st');
      }
      throw StateError('Could not reach the server. Check your connection.');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _trashMutationFromResponse(resp);
    }
    _throwFriendlyMutationFailure(
      resp,
      fallback: 'Could not move this story to Trash.',
    );
  }

  Future<PublishedMonoTrashMutationResult> restorePublishedMono(
      String id) async {
    final rid = id.trim();
    if (rid.isEmpty) {
      throw ArgumentError('publishedMono id is empty');
    }
    final uri = _u('/v1/published-monos/$rid/restore');
    http.Response resp;
    try {
      resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth(<String, String>{
          'Content-Type': 'application/json',
        }),
        (h) => _client.post(uri, headers: h),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RemotePublishedMonoRepository.restorePublishedMono error: '
            '$e\n$st');
      }
      throw StateError('Could not reach the server. Check your connection.');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _trashMutationFromResponse(resp);
    }
    final quota = tryParseQuotaExceededFromHttpBody(resp.body);
    if (quota != null) throw quota;
    _throwFriendlyMutationFailure(
      resp,
      fallback: 'Could not restore this story.',
    );
  }

  Future<PublishedMonoDetailDto> get(String id) async {
    final rid = id.trim();
    if (rid.isEmpty) {
      throw ArgumentError('publishedMono id is empty');
    }
    final detailUri = _u('/v1/published-monos/$rid');
    final resp = await _nimonAuthSend(
      detailUri,
      () => _mergeAuth({}),
      (h) => _client.get(detailUri, headers: h),
    );
    if (resp.statusCode == 404) {
      throw PublishedMonoHiddenWhileEditingException();
    }
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final it = m;
    return PublishedMonoDetailDto(
      id: _optStr(it['id']) ?? '',
      ownerId: _optStr(it['ownerId']) ?? '',
      sourceDraftId: readPublishedMonoSourceDraftIdFromJson(it),
      title: _optStr(it['title']) ?? '',
      category: _optStr(it['category']) ?? '',
      level: _optStr(it['level']) ?? '',
      description: _optStr(it['description']) ?? '',
      publishKind: _optStr(it['publishKind']),
      displayPublishKind: _optStr(it['displayPublishKind']) ?? 'unknown',
      coverImageUrl: _optStr(it['coverImageUrl']),
      targetDurationLabel: _optStr(it['targetDurationLabel']),
      createdAt: _optStr(it['createdAt']) ?? '',
      updatedAt: _optStr(it['updatedAt']) ?? '',
      contentSummary: it['contentSummary'],
      content: it['content'],
      shareUrl: _optStr(it['shareUrl']),
      writerDisplayName: _optStr(it['writerDisplayName']),
      writerHandle: _optStr(it['writerHandle']),
      writerAvatarUrl: _optStr(it['writerAvatarUrl']),
      likesCount: _jsonInt(it['likesCount']),
      isBookmarkedByMe: it['isBookmarkedByMe'] == true,
      myReaction: _optStr(it['myReaction']),
      contentLocale: _optStr(it['contentLocale']),
      learningLanguage: _optStr(it['learningLanguage']),
    );
  }

  Future<void> permanentlyDeletePublishedMono(String id) async {
    final rid = id.trim();
    if (rid.isEmpty) {
      throw ArgumentError('publishedMono id is empty');
    }
    final uri = _u('/v1/published-monos/$rid/permanent');
    http.Response resp;
    try {
      resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth(<String, String>{
          'Content-Type': 'application/json',
        }),
        (h) => _client.delete(
          uri,
          headers: h,
          body: jsonEncode(const {'confirm': 'DELETE'}),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.permanentlyDeletePublishedMono error: '
          '$e\n$st',
        );
      }
      throw StateError('Could not reach the server. Check your connection.');
    }

    if (resp.statusCode == 204 ||
        (resp.statusCode >= 200 && resp.statusCode < 300)) {
      return;
    }
    if (resp.statusCode == 404) {
      throw StateError('This story was already deleted.');
    }
    final quota = tryParseQuotaExceededFromHttpBody(resp.body);
    if (quota != null) throw quota;
    _throwFriendlyMutationFailure(
      resp,
      fallback: 'Could not permanently delete this story.',
    );
  }

  static int _jsonInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
