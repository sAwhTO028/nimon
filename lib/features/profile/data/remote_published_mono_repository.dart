import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

class RemotePublishedMonoRepository {
  RemotePublishedMonoRepository({
    required String apiBaseUrl,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'\/+$'), ''),
        _client = client ?? http.Client();

  final String _apiBaseUrl;
  final http.Client _client;

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
      sourceDraftId: _optStr(it['sourceDraftId']),
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
      final resp = await _client.get(uri);
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
      final resp = await _client.get(uri);
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

  Future<PublishedMonoDetailDto> get(String id) async {
    final rid = id.trim();
    if (rid.isEmpty) {
      throw ArgumentError('publishedMono id is empty');
    }
    final resp = await _client.get(_u('/v1/published-monos/$rid'));
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final it = m;
    return PublishedMonoDetailDto(
      id: _optStr(it['id']) ?? '',
      ownerId: _optStr(it['ownerId']) ?? '',
      sourceDraftId: _optStr(it['sourceDraftId']),
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
    );
  }
}
