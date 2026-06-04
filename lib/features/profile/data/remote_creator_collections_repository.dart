import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/quota_exceeded_from_json.dart';
import 'package:nimon/core/validation/validation_issue_from_json.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/auth/authenticated_http.dart';

import 'bulk_add_creator_collection_result.dart';
import 'creator_mono_collection.dart';
import 'published_mono_dto.dart';

typedef CreatorCollectionsAuthHeaderBuilder = Future<Map<String, String>>
    Function();

/// Paginated published monos inside a **public** creator collection.
class PublicCollectionMonosPage {
  const PublicCollectionMonosPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<PublishedMonoListItemDto> items;
  final String? nextCursor;
  final bool hasMore;
}

class RemoteCreatorCollectionsRepository {
  RemoteCreatorCollectionsRepository({
    required String apiBaseUrl,
    http.Client? client,
    CreatorCollectionsAuthHeaderBuilder? authHeaderBuilder,
    NimonSendWithAuth401Recovery? sendWithAuth401Recovery,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder,
        _sendWithAuth401 = sendWithAuth401Recovery;

  final String _apiBaseUrl;
  final http.Client _client;
  final CreatorCollectionsAuthHeaderBuilder? _authHeaderBuilder;
  final NimonSendWithAuth401Recovery? _sendWithAuth401;

  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

  Future<Map<String, String>> _mergeAuth(Map<String, String> headers) async {
    final builder = _authHeaderBuilder;
    if (builder == null) return headers;
    final auth = await builder();
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
      );

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Map<String, Object?> _jsonObject(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
  }

  String? _messageCode(http.Response r) {
    try {
      final m = _jsonObject(r);
      final msg = m['message'];
      if (msg is String) return msg.trim().isEmpty ? null : msg.trim();
      if (msg is List) {
        final parts =
            msg.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
        if (parts.isEmpty) return null;
        return parts.first.trim();
      }
    } catch (_) {}
    return null;
  }

  Never _throwMapped(http.Response r, {required String genericFallback}) {
    if (r.statusCode == 401) notifyIfStrictUnauthorized401(r);
    final quota = tryParseQuotaExceededFromHttpBody(r.body);
    if (quota != null) throw quota;
    final vf = tryParseValidationIssuesFromHttpBody(r.body);
    if (vf != null && vf.isNotEmpty) {
      throw HttpValidationFailedException(vf);
    }
    final code = _messageCode(r);
    if (r.statusCode == 401) {
      throw StateError('Sign in required.');
    }
    if (r.statusCode == 403 && code == 'not_owner_of_published_mono') {
      throw StateError(
        'You can only add your own published stories.',
      );
    }
    if (r.statusCode == 409 && code == 'collection_not_empty') {
      throw StateError('Remove all stories before deleting this collection.');
    }
    if (r.statusCode == 404 ||
        code == 'collection_not_found' ||
        code == 'collection_item_not_found') {
      throw StateError('Collection not found.');
    }
    if (code != null &&
        code.isNotEmpty &&
        code.length <= 200 &&
        !code.contains('\n')) {
      throw StateError(code);
    }
    throw StateError(genericFallback);
  }

  void _ensure2xx(http.Response r, {required String genericFallback}) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    _throwMapped(r, genericFallback: genericFallback);
  }

  Future<List<CreatorMonoCollection>> fetchMyCollections() async {
    try {
      final uri = _u('/v1/me/creator-collections');
      if (kDebugMode) {
        debugPrint('RemoteCreatorCollectionsRepository: GET $uri');
      }
      final resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth({'Accept': 'application/json'}),
        (h) => _client.get(uri, headers: h),
      );
      _ensure2xx(resp, genericFallback: 'Could not load collections.');
      final m = _jsonObject(resp);
      final raw = m['collections'];
      final list = raw is List ? raw : const [];
      final out = <CreatorMonoCollection>[];
      for (final x in list) {
        if (x is! Map) continue;
        final row = Map<String, Object?>.from(
          x.map((k, v) => MapEntry(k.toString(), v)),
        );
        out.add(CreatorMonoCollection.fromJson(row));
      }
      return out;
    } catch (e, st) {
      if (kDebugMode) debugPrint('fetchMyCollections error: $e\n$st');
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not load collections.');
    }
  }

  Future<CreatorMonoCollection> createCollection({
    required String title,
    String? description,
    String? coverImageUrl,
    String? visibility,
    int? sortOrder,
  }) async {
    final uri = _u('/v1/me/creator-collections');
    final body = <String, Object?>{
      'title': title,
      if (description != null) 'description': description,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      if (visibility != null) 'visibility': visibility,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
    final resp = await _nimonAuthSend(
      uri,
      () => _mergeAuth({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }),
      (h) => _client.post(uri, headers: h, body: jsonEncode(body)),
    );
    _ensure2xx(resp, genericFallback: 'Could not create collection.');
    final m = _jsonObject(resp);
    final raw = m['collection'];
    if (raw is! Map) {
      throw StateError('Could not create collection.');
    }
    final row = Map<String, Object?>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    return CreatorMonoCollection.fromJson(row);
  }

  Future<CreatorMonoCollection> updateCollection(
    String id, {
    String? title,
    String? description,
    String? coverImageUrl,
    String? visibility,
    int? sortOrder,
  }) async {
    final uri = _u('/v1/me/creator-collections/$id');
    final body = <String, Object?>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      if (visibility != null) 'visibility': visibility,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
    final resp = await _nimonAuthSend(
      uri,
      () => _mergeAuth({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }),
      (h) => _client.patch(uri, headers: h, body: jsonEncode(body)),
    );
    _ensure2xx(resp, genericFallback: 'Could not update collection.');
    final m = _jsonObject(resp);
    final raw = m['collection'];
    if (raw is! Map) {
      throw StateError('Could not update collection.');
    }
    final row = Map<String, Object?>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    return CreatorMonoCollection.fromJson(row);
  }

  Future<void> deleteCollection(String id) async {
    final uri = _u('/v1/me/creator-collections/$id');
    final resp = await _nimonAuthSend(
      uri,
      () => _mergeAuth({'Accept': 'application/json'}),
      (h) => _client.delete(uri, headers: h),
    );
    if (resp.statusCode == 204) return;
    _ensure2xx(resp, genericFallback: 'Could not delete collection.');
  }

  Future<({bool created, String itemId})> addItem(
    String collectionId,
    String publishedMonoId,
  ) async {
    final uri = _u('/v1/me/creator-collections/$collectionId/items');
    final resp = await _nimonAuthSend(
      uri,
      () => _mergeAuth({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }),
      (h) => _client.post(
        uri,
        headers: h,
        body: jsonEncode({'publishedMonoId': publishedMonoId}),
      ),
    );
    _ensure2xx(resp, genericFallback: 'Could not add to collection.');
    final m = _jsonObject(resp);
    final created = m['created'] == true;
    final itemId = (m['itemId'] ?? '').toString();
    return (created: created, itemId: itemId);
  }

  Future<void> removeItem(String collectionId, String publishedMonoId) async {
    final uri = _u(
      '/v1/me/creator-collections/$collectionId/items/$publishedMonoId',
    );
    final resp = await _nimonAuthSend(
      uri,
      () => _mergeAuth({'Accept': 'application/json'}),
      (h) => _client.delete(uri, headers: h),
    );
    if (resp.statusCode == 204) return;
    _ensure2xx(resp, genericFallback: 'Could not remove from collection.');
  }

  /// Public; optional auth headers (guest-safe).
  Future<List<CreatorMonoCollection>> fetchPublicCollections(
    String userId,
  ) async {
    final uid = userId.trim();
    if (uid.isEmpty) throw ArgumentError('userId is empty');
    try {
      final uri = _u('/v1/users/$uid/creator-collections');
      if (kDebugMode) {
        debugPrint('RemoteCreatorCollectionsRepository: GET $uri');
      }
      final headers = await _mergeAuth({'Accept': 'application/json'});
      final resp = await _nimonAuthSend(
        uri,
        () => Future.value(headers),
        (h) => _client.get(uri, headers: h),
      );
      _ensure2xx(resp, genericFallback: 'Could not load collections.');
      final m = _jsonObject(resp);
      final raw = m['collections'];
      final list = raw is List ? raw : const [];
      if (kDebugMode) {
        debugPrint(
          'fetchPublicCollections: status=${resp.statusCode} count=${list.length} '
          'authPresent=${headers.containsKey('Authorization')}',
        );
      }
      final out = <CreatorMonoCollection>[];
      for (final x in list) {
        if (x is! Map) continue;
        final row = Map<String, Object?>.from(
          x.map((k, v) => MapEntry(k.toString(), v)),
        );
        out.add(CreatorMonoCollection.fromJson(row));
      }
      return out;
    } catch (e, st) {
      if (kDebugMode) debugPrint('fetchPublicCollections error: $e\n$st');
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not load collections.');
    }
  }

  /// Public; optional auth headers (guest-safe).
  Future<PublicCollectionMonosPage> fetchPublicCollectionMonos(
    String userId,
    String collectionId, {
    String? cursor,
    int? limit,
  }) async {
    final uid = userId.trim();
    final cid = collectionId.trim();
    if (uid.isEmpty) throw ArgumentError('userId is empty');
    if (cid.isEmpty) throw ArgumentError('collectionId is empty');
    try {
      final qp = <String, String>{};
      final c = cursor?.trim();
      if (c != null && c.isNotEmpty) qp['cursor'] = c;
      if (limit != null) qp['limit'] = '$limit';
      final base = _u('/v1/users/$uid/creator-collections/$cid/monos');
      final uri = qp.isEmpty ? base : base.replace(queryParameters: qp);
      if (kDebugMode) {
        debugPrint('RemoteCreatorCollectionsRepository: GET $uri');
      }
      final headers = await _mergeAuth({'Accept': 'application/json'});
      final resp = await _nimonAuthSend(
        uri,
        () => Future.value(headers),
        (h) => _client.get(uri, headers: h),
      );
      _ensure2xx(resp, genericFallback: 'Could not load stories.');
      final m = _jsonObject(resp);
      final rawItems = (m['items'] as List?) ?? const [];
      if (kDebugMode) {
        debugPrint(
          'fetchPublicCollectionMonos: status=${resp.statusCode} itemCount=${rawItems.length} '
          'authPresent=${headers.containsKey('Authorization')}',
        );
      }
      final items = <PublishedMonoListItemDto>[];
      for (final x in rawItems) {
        if (x is! Map) continue;
        final it = Map<String, Object?>.from(
          x.map((k, v) => MapEntry(k.toString(), v)),
        );
        items.add(publishedMonoListItemDtoFromBackendJson(it));
      }
      final next = () {
        final v = m['nextCursor'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }();
      final hasMoreFlag = m['hasMore'];
      final hasMore =
          hasMoreFlag is bool ? hasMoreFlag : (next != null && next.isNotEmpty);
      return PublicCollectionMonosPage(
        items: items,
        nextCursor: next,
        hasMore: hasMore,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('fetchPublicCollectionMonos error: $e\n$st');
      }
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not load stories.');
    }
  }

  Future<PublicCollectionMonosPage> fetchMyCollectionMonos(
    String collectionId, {
    String? cursor,
    int? limit,
  }) async {
    final cid = collectionId.trim();
    if (cid.isEmpty) throw ArgumentError('collectionId is empty');
    try {
      final qp = <String, String>{};
      final c = cursor?.trim();
      if (c != null && c.isNotEmpty) qp['cursor'] = c;
      if (limit != null) qp['limit'] = '$limit';
      final base = _u('/v1/me/creator-collections/$cid/monos');
      final uri = qp.isEmpty ? base : base.replace(queryParameters: qp);
      if (kDebugMode) {
        debugPrint('RemoteCreatorCollectionsRepository: GET $uri');
      }
      final resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth({'Accept': 'application/json'}),
        (h) => _client.get(uri, headers: h),
      );
      _ensure2xx(resp, genericFallback: 'Could not load stories.');
      final m = _jsonObject(resp);
      final rawItems = (m['items'] as List?) ?? const [];
      final items = <PublishedMonoListItemDto>[];
      for (final x in rawItems) {
        if (x is! Map) continue;
        final it = Map<String, Object?>.from(
          x.map((k, v) => MapEntry(k.toString(), v)),
        );
        items.add(publishedMonoListItemDtoFromBackendJson(it));
      }
      final next = () {
        final v = m['nextCursor'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }();
      final hasMoreFlag = m['hasMore'];
      final hasMore =
          hasMoreFlag is bool ? hasMoreFlag : (next != null && next.isNotEmpty);
      return PublicCollectionMonosPage(
        items: items,
        nextCursor: next,
        hasMore: hasMore,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('fetchMyCollectionMonos error: $e\n$st');
      }
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not load stories.');
    }
  }

  Future<BulkAddCreatorCollectionResult> bulkAddItems(
    String collectionId,
    List<String> publishedMonoIds,
  ) async {
    final uri = _u('/v1/me/creator-collections/$collectionId/items/bulk');
    final resp = await _nimonAuthSend(
      uri,
      () => _mergeAuth({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }),
      (h) => _client.post(
        uri,
        headers: h,
        body: jsonEncode({'publishedMonoIds': publishedMonoIds}),
      ),
    );
    _ensure2xx(resp, genericFallback: 'Could not update collection.');
    final m = _jsonObject(resp);
    return BulkAddCreatorCollectionResult.fromJson(m);
  }
}
