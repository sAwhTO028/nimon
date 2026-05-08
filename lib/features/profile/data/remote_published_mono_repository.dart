import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

typedef PublishedMonoAuthHeaderBuilder = Future<Map<String, String>> Function();

class RemotePublishedMonoRepository {
  RemotePublishedMonoRepository({
    required String apiBaseUrl,
    http.Client? client,
    PublishedMonoAuthHeaderBuilder? authHeaderBuilder,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'\/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder;

  final String _apiBaseUrl;
  final http.Client _client;
  final PublishedMonoAuthHeaderBuilder? _authHeaderBuilder;

  Future<Map<String, String>> _mergeAuth(Map<String, String> headers) async {
    final builder = _authHeaderBuilder;
    if (builder == null) return headers;
    final auth = await builder();
    return {...auth, ...headers};
  }

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
    notifyIfStrictUnauthorized401(r);
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
    final v = m['hasMore'];
    if (v is bool) return v;
    return false;
  }

  int? _totalCountFromJson(Map<String, Object?> m) {
    final v = m['totalCount'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  PublishedMonoListItemDto _listItemFromMap(Map<String, Object?> it) {
    return PublishedMonoListItemDto(
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
      trashedAt: _optStr(it['trashedAt']),
      writerDisplayName: _optStr(it['writerDisplayName']),
      writerHandle: _optStr(it['writerHandle']),
      writerAvatarUrl: _optStr(it['writerAvatarUrl']),
    );
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
    notifyIfStrictUnauthorized401(r);
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
    final rawItems = (m['items'] as List?) ?? const [];
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
      nextCursor: _optStr(m['nextCursor']),
      hasMore: _hasMoreFromJson(m),
      totalCount: _totalCountFromJson(m),
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

  Future<PublishedMonoListResponseDto> list({int limit = 50}) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'RemotePublishedMonoRepository.list: GET /v1/published-monos?limit=$limit',
        );
      }
      final uri = _publishedMonosListUri({'limit': '$limit'});
      final resp = await _client.get(uri, headers: await _mergeAuth({}));
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
      final resp = await _client.get(uri, headers: await _mergeAuth({}));
      _throwIfNotOk(resp);
      final m = _jsonObjectFromResponse(resp);
      final dto = _listResponseDtoFromMap(m);
      if (kDebugMode) {
        final rawItems = (m['items'] as List?) ?? const [];
        debugPrint(
          'RemotePublishedMonoRepository.fetchPage: JSON items=${rawItems.length} parsedDtos=${dto.items.length} hasMore=${dto.hasMore}',
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
      final resp = await _client.get(uri, headers: await _mergeAuth({}));
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
      resp = await _client.post(
        uri,
        headers: await _mergeAuth(<String, String>{
          'Content-Type': 'application/json',
        }),
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
      resp = await _client.post(
        uri,
        headers: await _mergeAuth(<String, String>{
          'Content-Type': 'application/json',
        }),
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
    final resp = await _client.get(
      _u('/v1/published-monos/$rid'),
      headers: await _mergeAuth({}),
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
      writerDisplayName: _optStr(it['writerDisplayName']),
      writerHandle: _optStr(it['writerHandle']),
      writerAvatarUrl: _optStr(it['writerAvatarUrl']),
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
      resp = await _client.delete(
        uri,
        headers: await _mergeAuth(<String, String>{
          'Content-Type': 'application/json',
        }),
        body: jsonEncode(const {'confirm': 'DELETE'}),
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
      notifyIfStrictUnauthorized401(resp);
      throw StateError('This story was already deleted.');
    }
    _throwFriendlyMutationFailure(
      resp,
      fallback: 'Could not permanently delete this story.',
    );
  }
}
